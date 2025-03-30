{-# LANGUAGE TemplateHaskell #-}

module Article where

import Config (Config (..))
import Config qualified
import Control.Monad (filterM, (>=>))
import Data.Bifunctor (Bifunctor (first), second)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Either (isLeft)
import Data.FileEmbed (embedStringFile)
import Data.List (find, intercalate, isSuffixOf, sortBy)
import Data.Maybe (catMaybes, fromJust)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Data.Time (defaultTimeLocale, formatTime, fromGregorian)
import Index (findAndReplace)
import Index qualified
import System.Directory
  ( doesDirectoryExist,
    getDirectoryContents,
  )
import System.FilePath (combine)
import System.IO.Error

green :: String -> String
green s = "\ESC[1;32m" ++ s ++ "\ESC[0m"

orange :: String -> String
orange s = "\ESC[1;38;5;208m" ++ s ++ "\ESC[0m"

type IOResult = Either IOError

data FEntry
  = File FilePath ByteString
  | Directory FilePath (Maybe [FEntry])
  deriving (Show)

isSpecialPath :: FilePath -> IO Bool
isSpecialPath ".." = return True
isSpecialPath "." = return True
isSpecialPath _ = return False

fileTree :: Int -> FilePath -> IO (IOResult FEntry)
fileTree n path = do
  fileContents <- tryIOError (ByteString.readFile path)
  case fileContents of
    Right contents -> return (Right (File path contents))
    _ -> dir n path
  where
    dir :: Int -> FilePath -> IO (IOResult FEntry)
    dir 1 path' = do
      exists <- doesDirectoryExist path'
      if exists
        then return $ Right (Directory path' Nothing)
        -- TODO: This error message is garbage (but shouldn't be hit)
        else return $ Left (mkIOError doesNotExistErrorType "" Nothing Nothing)
    dir n' path' = do
      entries <- tryIOError (getDirectoryContents path')
      case entries of
        Right xs -> do
          filtXs <- filterM (isSpecialPath >=> (return . not)) xs
          let mapXs = (path' `combine`) <$> filtXs
          xs' <- mapM (fileTree (n' - 1)) mapXs
          return $ second (Directory path' . Just) (sequenceA xs')
        Left e -> return (Left e)

data ArticleError
  = BadConfig Config.Error
  | BadStructure
  | MissingConfig
  | MissingIndex

warnArticleError :: FilePath -> ArticleError -> IO ()
warnArticleError path e = putStrLn (pfx ++ msg)
  where
    pfx = orange "WARNING" ++ ": failed generating " ++ path ++ ":\n  "
    msg = case e of
      MissingIndex -> "missing index.md"
      MissingConfig -> "missing config.toml"
      BadStructure -> "bad article structure"
      BadConfig (Config.EConfig s) -> s
      BadConfig (Config.EToml s) -> s

data Article = Article
  { config :: Config,
    content :: [Index.Block]
  }

justOr :: e -> Maybe a -> Either e a
justOr _ (Just a) = Right a
justOr e Nothing = Left e

-- Helper to make the article, but no IO
makeArticle :: [FEntry] -> Either ArticleError Article
makeArticle fes = do
  (_, indexContent) <-
    justOr MissingIndex $ find (("index.md" `isSuffixOf`) . fst) files
  (_, configContent) <-
    justOr MissingConfig $ find (("config.toml" `isSuffixOf`) . fst) files
  config <- first BadConfig (Config.parseConfig (decode configContent))
  let index = fromJust $ Index.parseMarkdown (Text.unpack (decode indexContent))
  return $
    Article
      { config,
        content = index
      }
  where
    push (File path contents) fs = (path, contents) : fs
    push _ fs = fs
    files = foldr push [] fes
    decode = Text.decodeUtf8Lenient

writeArticleToFile :: FEntry -> IO (Maybe (String, Config))
writeArticleToFile (Directory articlePath (Just fes)) = do
  let indexHtmlPath = articlePath `combine` "index.html"
  case makeArticle fes of
    Left e -> do
      warnArticleError articlePath e
      return Nothing
    Right art@(Article {config}) -> do
      e <- tryIOError (writeFile indexHtmlPath (indexHtml art))
      if isLeft e
        then do
          warnArticleError articlePath BadStructure
          return Nothing
        else do
          putStrLn (green "SUCCESS: " ++ "generated " ++ indexHtmlPath)
          return (Just (articlePath, config))
-- Just skip anything that's not a directory
writeArticleToFile _ = return Nothing

makeBlog :: String -> IO (IOResult ())
makeBlog blogPath = do
  tree <- fileTree 3 blogPath
  case tree of
    Right fe -> do
      _ <- writeBlog fe
      return (Right ())
    Left e -> return (Left e)
  where
    writeBlog tree = case tree of
      Directory _ (Just fes) -> do
        cfgs <- mapM writeArticleToFile fes
        let cfgs' = catMaybes cfgs
        let blogEntries = sortBy (\x y -> snd y `compare` snd x) cfgs'
        let blogEntries' = concatMap (uncurry configToHtml) blogEntries
        writeFile
          "./index.html"
          (findAndReplace "BLOG_ENTRIES" blogEntries' homeHtmlT)
        return ()
      _ -> putStrLn $ "ERROR  : " ++ blogPath ++ " is not a directory"

-- CONVERTING ARTICLES TO HTML -------------------------------------------------

formatDate :: (Int, Int, Int) -> String
formatDate (y, m, d) = formatTime defaultTimeLocale "%B %e, %Y" day
  where
    day = fromGregorian (toInteger y) m d

headHtmlT :: String
headHtmlT = $(embedStringFile "./src/template.html")

indexHtml :: Article -> String
indexHtml
  ( Article
      { config = Config {title, authors, keywords, date},
        content
      }
    ) =
    ( ( if Index.hasMath content
          then findAndReplace "MATH" "-->" . findAndReplace "ENDMATH" "<!--"
          else id
      )
        . findAndReplace "ARTICLE" (Index.blocksToHtml content)
        . findAndReplace "KEYWORDS" (intercalate ", " keywords)
        . findAndReplace "AUTHOR" (intercalate ", " authors)
        . findAndReplace "TITLE" title
        . findAndReplace "DATE" (formatDate date)
    )
      headHtmlT

configHtmlT :: String
configHtmlT = $(embedStringFile "./src/config-template.html")

homeHtmlT :: String
homeHtmlT = $(embedStringFile "./src/home-template.html")

configToHtml :: String -> Config -> String
configToHtml path (Config {date, description, title}) =
  ( findAndReplace "TITLE" title
      . findAndReplace "DATE" (formatDate date)
      . findAndReplace "LINK" path
      . findAndReplace "DESCRIPTION" description
  )
    configHtmlT