module Md where

import Data.Bifunctor (first, second)
import Data.List (isPrefixOf)
import Data.Maybe (fromJust)

--------------------------------------------------------------------------------

type Parser a b = [a] -> Maybe ([a], b)

-- Parse exactly `str` or fail
exactly :: (Eq a) => [a] -> Parser a [a]
exactly str input
  | str `isPrefixOf` input = Just (drop (length str) input, str)
  | otherwise = Nothing

exactly' :: (Eq a) => [a] -> Parser a ()
exactly' str input = (input, ()) <$ exactly str input

peek :: Parser a b -> Parser a b
peek p input = first (const input) <$> p input

-- sequence parser
thn :: Parser a b -> Parser a c -> Parser a (b, c)
thn pa pb input = do
  (input', a) <- pa input
  (input'', b) <- pb input'
  return (input'', (a, b))

pmap :: (b -> c) -> Parser a b -> Parser a c
pmap f p input = do
  (input', b) <- p input
  Just (input', f b)

thn1 :: Parser a b1 -> Parser a b2 -> Parser a b1
thn1 p1 p2 = pmap fst (p1 `thn` p2)

thn2 :: Parser a b1 -> Parser a b2 -> Parser a b2
thn2 p1 p2 = pmap snd (p1 `thn` p2)

-- parse everything, until p matches
utl :: Parser a b -> Parser a ([a], b)
utl p = utl' []
  where
    utl' _ [] = Nothing -- never matched p
    utl' s input'@(c : cs) = case p input' of
      Just (input'', a) -> Just (input'', (reverse s, a))
      Nothing -> utl' (c : s) cs

stop :: Parser a b -> Parser a [a]
stop p = pmap fst (utl (peek p))

-- alternative parser (first match)
alt :: [Parser a b] -> Parser a b
alt [] _ = Nothing
alt (p : ps) input = case p input of
  Nothing -> alt ps input
  happy -> happy

-- repeat in sequence utl failure, more general than `rep`
rep' :: (Monoid t) => (b -> t -> t) -> Parser a b -> Parser a t
rep' _ _ [] = Nothing
rep' with p input = do
  (input', a) <- p input
  Just $ case rep' with p input' of
    Just (input'', as) -> (input'', a `with` as)
    Nothing -> (input', a `with` mempty)

-- repeat in sequence utl failure `Nothing` is the empty list
rep :: Parser a b -> Parser a [b]
rep = rep' (:)

-- turns a parser into one that never fails
opt :: Parser a b -> Parser a (Maybe b)
opt p input = case p input of
  Just (input', a) -> Just (input', Just a)
  Nothing -> Just (input, Nothing)

-- takes two delimiters and a central parser, and applies
-- This is O(n) time, so using it for recursive calls (e.g. to parse "(((())))")
-- is, of course, suboptimal.. but easy :)
-- OPTIMIZATION: change the way we use this
delimited :: forall a. (Eq a) => ([a] -> Bool) -> [a] -> [a] -> Parser a [a]
delimited exit ldelim rdelim input = do
  (input', _) <- exactly ldelim input
  delimited' 1 [] input'
  where
    delimited' :: Int -> [a] -> Parser a [a]
    delimited' n xs ys
      | n == 0 = Just (ys, reverse (drop (length rdelim) xs))
      | exit ys || null ys = Nothing
      | rdelim `isPrefixOf` ys = cont (n - 1) rdelim
      | ldelim `isPrefixOf` ys = cont (n + 1) ldelim
      | otherwise = cont n [head ys]
      where
        cont m str = delimited' m (reverse str ++ xs) (drop (length str) ys)

-- TOKENIZER -------------------------------------------------------------------

data Token = Eof | LineStart | Ch Char deriving (Show, Eq)

invToken :: Token -> Char
invToken (Ch c) = c
invToken LineStart = '\n'
invToken Eof = '?'

parseCh :: Parser Char Token
parseCh ('\\' : c : input') = Just (input', Ch c)
parseCh (c : input') = Just (input', Ch c)
parseCh "" = Nothing

parseLineStart :: Parser Char Token
parseLineStart = (second (const LineStart) <$>) . exactly "\n"

tokenize :: Parser Char [Token]
tokenize =
  pmap ((LineStart :) . (++ [Eof])) (rep (alt [parseLineStart, parseCh]))

-- PARSER ----------------------------------------------------------------------

-- Decorate certain lines of text, for example **bold** or *italic* or `code`
data Inline
  = Bold [Inline]
  | Italic [Inline]
  | Code String
  | Plaintext String
  deriving (Show, Eq)

parseInline :: [Token] -> ([Token], [Inline])
parseInline = multiple
  where
    tkDelimited ldelim rdelim =
      delimited (const False) (Ch <$> ldelim) (Ch <$> rdelim)

    -- We build the 'fallible' parser from both the recursive variants and the
    -- plaintext variant. If both fail, we just need to consume as [Plaintext]
    -- utl we find a success
    -- Bold+Italic: for any POSIX grammar, we must have this be a special
    --              case! This is not an accident.
    recursive =
      alt
        [ pmap (Bold . (: []) . Italic,) (tkDelimited "***" "***"),
          pmap (Bold,) (tkDelimited "**" "**"),
          pmap (Italic,) (tkDelimited "*" "*")
        ]
    simple =
      alt
        [ pmap (Code,) (tkDelimited "`" "`")
        ]
    fallible input = case recursive input of
      Just (input', (t, inner)) -> Just (input', t (snd (multiple inner)))
      Nothing -> case simple input of
        Just (input', (t, inner)) -> Just (input', t (invToken <$> inner))
        Nothing -> Nothing
    plaintext = Plaintext . (invToken <$>)
    single =
      alt
        [ pmap (: []) fallible,
          -- get some plaintext up until we find a new 'fallible'
          pmap (\(a, b) -> [plaintext a, b]) (utl fallible),
          -- backup, get everything up until linebreak
          Just . ([],) . (: []) . plaintext
        ]
    -- we could prove that this never fails...
    multiple = fromJust . rep' (++) single

data Block
  = LineBreak
  | Paragraph [Inline]
  | Heading Int [Inline]
  | CodeBlock String String
  deriving (Show)

parseLineEnd :: Parser Token [Token]
parseLineEnd = alt [exactly [LineStart], exactly [Eof]]

parseLineBreak :: Parser Token Block
parseLineBreak =
  pmap
    (const LineBreak)
    (alt [exactly [LineStart] `thn1` exactly' [LineStart], exactly [Eof]])

parseParagraph :: Parser Token Block
parseParagraph input = do
  (input', (text, _)) <- utl parseLineBreak input
  Just (input', Paragraph (snd (parseInline text)))

ignoreLineStart :: Parser Token (Maybe [Token])
ignoreLineStart = opt (exactly [LineStart])

-- TODO: this is kind of gross code?
parseHeading :: Parser Token Block
parseHeading input = do
  let optWhitespace = opt (rep (exactly [Ch ' ']))
  (input1, _) <- ignoreLineStart input
  (input2, hashtags) <- (rep (exactly [Ch '#']) `thn1` optWhitespace) input1
  (input3, (title, _)) <- utl parseLineEnd input2
  Just (input3, Heading (length hashtags) (snd (parseInline title)))

parseCodeBlock :: Parser Token Block
parseCodeBlock input = do
  let delim = exactly (Ch <$> "```")
  (input1, _) <- (ignoreLineStart `thn2` delim) input
  (input2, (lang, _)) <- utl (exactly [LineStart]) input1
  (input3, (text, _)) <- utl delim input2
  return (input3, CodeBlock (invToken <$> lang) (invToken <$> text))

parseBlocks :: Parser Token [Block]
parseBlocks =
  rep
    ( alt
        [ parseLineBreak,
          parseHeading,
          parseCodeBlock,
          parseParagraph
        ]
    )

parseMarkdown :: String -> Maybe [Block]
parseMarkdown input = do
  (_, tokens) <- tokenize input -- TODO: this shouldn't fail...
  (tokens', blocks) <- parseBlocks tokens
  if null tokens' then Just blocks else Nothing

-- HTML ------------------------------------------------------------------------

tag :: String -> String -> String
tag t stuff = "<" ++ t ++ ">" ++ stuff ++ "</" ++ t ++ ">"

inlinesToHtml :: [Inline] -> String
inlinesToHtml = concatMap inlineToHtml

inlineToHtml :: Inline -> String
inlineToHtml (Plaintext str) = str
inlineToHtml (Code str) = tag "code" str
inlineToHtml (Italic xs) = tag "i" (inlinesToHtml xs)
inlineToHtml (Bold xs) = tag "b" (inlinesToHtml xs)

blocksToHtml :: [Block] -> String
blocksToHtml = concatMap blockToHtml

blockToHtml :: Block -> String
blockToHtml LineBreak = "<br/>"
blockToHtml (Paragraph xs) = tag "p" (inlinesToHtml xs)
blockToHtml (Heading n str) = tag ("h" ++ show (min 6 n)) (inlinesToHtml str)
blockToHtml (CodeBlock lang text) =
  "<div language=\"" ++ lang ++ "\">\n" ++ tag "pre" text ++ "</div>"