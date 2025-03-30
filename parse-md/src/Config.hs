module Config where

-- This file parses the config record from the .toml file
-- It uses tomland's toml-parser for its support of TOML v1.0.0, but it's very
-- hard to find documentation about how it works :/

import Data.Bifunctor (first)
import Data.Map (Map)
import Data.Map qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time.Calendar (toGregorian)
import Toml qualified

data Config = Config
  { title :: String,
    description :: String,
    date :: (Int, Int, Int), -- year, month, day
    keywords :: [String],
    authors :: [String]
  }
  deriving (Show)

data Error
  = EToml String
  | EConfig String
  deriving (Show)

type Result a = Either Error a

orDefault :: p -> Either a p -> p
orDefault d (Left _) = d
orDefault _ (Right d) = d

type TomlValue = Toml.Value' Toml.Position

type TomlTable = Toml.Table' Toml.Position

type TomlMap = Map Text (Toml.Position, TomlValue)

fqKey :: [String] -> [Char]
fqKey [] = ""
fqKey [x] = x
fqKey (x : xs) = x ++ "." ++ fqKey xs

-- Get something like "a.b.c" looping recursively through the structure, fails
-- with a string error if anything goes wrong
tableGet :: [String] -> TomlMap -> Result TomlValue
tableGet ks tbl = get' tbl (Text.pack <$> ks)
  where
    err = EConfig ("could not find key " ++ fqKey ks)
    get' _ [] = undefined -- impossible key
    get' t [k] = case Map.lookup k t of
      Just v -> Right (snd v)
      Nothing -> Left err
    get' t (k : kt) = case Map.lookup k t of
      Just (_, Toml.Table' _ (Toml.MkTable t')) -> get' t' kt
      _ -> Left err

typeError :: String -> String -> Error
typeError ident ty = EConfig (ident ++ " is not a " ++ ty)

tyString :: TomlValue -> Maybe String
tyString (Toml.Text' _ str) = return (Text.unpack str)
tyString _ = Nothing

tyDate :: TomlValue -> Maybe (Int, Int, Int)
tyDate (Toml.Day' _ day) =
  let (y, m, d) = toGregorian day in Just (fromInteger y, m, d)
tyDate _ = Nothing

tyArray :: (TomlValue -> Maybe a) -> TomlValue -> Maybe [a]
tyArray conv (Toml.List' _ xs) = convertAll xs
  where
    convertAll [] = Just []
    convertAll (a : as) = case conv a of
      Just a' -> (a' :) <$> convertAll as
      Nothing -> Nothing
tyArray _ _ = Nothing

tyAuthor :: TomlValue -> Maybe String
tyAuthor (Toml.Table' _ (Toml.MkTable t)) = case readAs tyString ["name"] t of
  Left _ -> Nothing
  Right v -> Just v
tyAuthor _ = Nothing

readAs :: (TomlValue -> Maybe a) -> [String] -> TomlMap -> Result a
readAs conv ks tbl = do
  val <- tableGet ks tbl
  case conv val of
    Just v -> Right v
    Nothing -> Left (EConfig (fqKey ks ++ " is not the correct type"))

readConfig :: TomlTable -> Result Config
readConfig (Toml.MkTable tbl) = do
  title <- readAs tyString ["title"] tbl
  description <- readAs tyString ["description"] tbl
  date <- readAs tyDate ["date"] tbl
  let readAsStringArray = readAs (tyArray tyString) ["meta", "keywords"]
  let keywords = orDefault [] $ readAsStringArray tbl
  let authors = orDefault ["Unknown"] $ readAs (tyArray tyAuthor) ["author"] tbl
  return $
    Config
      { title,
        description,
        date,
        keywords,
        authors
      }

parseConfig :: Text -> Result Config
parseConfig text = do
  toml <- first EToml (Toml.parse text)
  readConfig toml

