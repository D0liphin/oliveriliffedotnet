module Index where

import Data.Bifunctor (Bifunctor (first), second)
import Data.List (isPrefixOf)
import Data.Maybe (fromJust, fromMaybe)

--------------------------------------------------------------------------------

type Parser a b = [a] -> Maybe ([a], b)

-- Parse exactly `str` or fail
exactly :: (Eq a) => [a] -> Parser a [a]
exactly str input
  | str `isPrefixOf` input = Just (drop (length str) input, str)
  | otherwise = Nothing

exactly' :: (Eq a) => [a] -> Parser a ()
exactly' str input = (input, ()) <$ exactly str input

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

findAndReplace :: (Eq a) => [a] -> [a] -> [a] -> [a]
findAndReplace find replace = f []
  where
    f str' [] = reverse str'
    f str' cs@(c : ct)
      | find `isPrefixOf` cs =
          f (reverse replace ++ str') (drop (length find) cs)
      | otherwise = f (c : str') ct

eth :: Parser a b -> Parser a c -> Parser a (Either b c)
eth pl pr input = case pmap Left pl input of
  Nothing -> pmap Right pr input
  happy -> happy

-- TOKENIZER -------------------------------------------------------------------

data Token = Eof | Newline | Ch Char deriving (Show, Eq)

invToken :: Token -> Char
invToken (Ch c) = c
invToken Newline = '\n'
invToken Eof = '\n'

parseCh :: Parser Char Token
parseCh ('\\' : c : input')
  | c `elem` ['*', '>', '$', '!'] = Just (input', Ch c)
parseCh (c : input') = Just (input', Ch c)
parseCh "" = Nothing

parseNewline :: Parser Char Token
parseNewline = (second (const Newline) <$>) . exactly "\n"

tokenize :: Parser Char [Token]
tokenize =
  pmap (++ [Eof]) (rep (alt [parseNewline, parseCh]))

-- PARSER ----------------------------------------------------------------------

parseUInt :: Parser Token Word
parseUInt = pmap (read :: String -> Word) parseUInt'
  where
    parseUInt' = pmap (invToken <$>) (rep' (++) parseDigit)
    parseDigit = alt (exactly . (: []) . Ch <$> "0123456789")

-- Decorate certain lines of text, for example **bold** or *italic* or `code`
data Inline
  = Bold [Inline]
  | Italic [Inline]
  | Code String
  | Image String String
  | Link String String
  | Plaintext String
  | Equation String
  | MathBlock String
  deriving (Show, Eq)

parseAltSrc :: Parser Token (String, String)
parseAltSrc input = do
  (input1, (a, s)) <- (tkDelimited "[" "]" `thn` tkDelimited "(" ")") input
  return (input1, (invToken <$> a, invToken <$> s))

parseImage :: Parser Token Inline
parseImage = pmap (uncurry Image) (exactly [Ch '!'] `thn2` parseAltSrc)

parseLink :: Parser Token Inline
parseLink = pmap (uncurry Link) parseAltSrc

tkDelimited :: String -> String -> Parser Token [Token]
tkDelimited ldelim rdelim =
  delimited (const False) (Ch <$> ldelim) (Ch <$> rdelim)

simpleDelimited :: (String -> c) -> String -> String -> Parser Token c
simpleDelimited t ld rd = pmap (t . (invToken <$>)) (tkDelimited ld rd)

parseCode :: Parser Token Inline
parseCode = simpleDelimited Code "`" "`"

parseInline :: [Token] -> ([Token], [Inline])
parseInline = multiple
  where
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
        [ simpleDelimited Code "`" "`",
          simpleDelimited MathBlock "$$" "$$",
          simpleDelimited Equation "$" "$",
          parseImage,
          parseLink
        ]
    fallible input = case recursive input of
      Just (input', (t, inner)) -> Just (input', t (snd (multiple inner)))
      Nothing -> case simple input of
        Just (input', inline) -> Just (input', inline)
        Nothing -> Nothing
    plaintext = Plaintext . (invToken <$>)
    single =
      alt
        [ pmap (: []) fallible,
          -- get some plaintext up until we find a new 'fallible'
          pmap (\(a, b) -> [plaintext a, b]) (utl fallible),
          -- backup, get everything
          Just . ([],) . (: []) . plaintext
        ]
    -- we could prove that this never fails...
    multiple = fromJust . rep' (++) single

data Block
  = LineBreak Int
  | Paragraph [Inline]
  | Quote [Block]
  | Heading Int [Inline]
  | UList [[Block]]
  | OList [[Block]]
  | CodeBlock String String
  deriving (Show)

parseLineEnd :: Parser Token [Token]
parseLineEnd = alt [exactly [Newline], exactly [Eof]]

parseLineBreak :: Parser Token Block
parseLineBreak input = do
  let eof = exactly [Eof]
  let nl = exactly [Newline]
  (input', brs) <- alt [rep nl `thn1` opt eof, pmap (: []) eof] input
  return (input', LineBreak (length brs - 2))

parseHeading :: Parser Token Block
parseHeading input = do
  let optWhitespace = opt (rep (exactly [Ch ' ']))
  (input1, hashtags) <- (rep (exactly [Ch '#']) `thn1` optWhitespace) input
  (input2, (title, _)) <- utl parseLineEnd input1
  return (input2, Heading (length hashtags) (snd (parseInline title)))

parseCodeBlock :: Parser Token Block
parseCodeBlock input = do
  let delim = exactly (Ch <$> "```")
  (input1, _) <- delim input
  (input2, (lang, _)) <- utl (exactly [Newline]) input1
  (input3, (text, _)) <- utl delim input2
  return (input3, CodeBlock (invToken <$> lang) (invToken <$> text))

parseQuote :: Parser Token Block
parseQuote input = do
  (input', (text, _)) <- (exactly [Ch '>'] `thn2` utl endQuote) input
  let text' = findAndReplace [Newline, Ch '>'] [Newline] text
  (_, inner) <- parseBlocks (text' ++ [Eof])
  return (input', Quote inner)
  where
    endQuote (Newline : Ch '>' : _) = Nothing
    endQuote (nl : input')
      | nl == Newline || nl == Eof = Just (input', ())
    endQuote _ = Nothing

parseUList :: Parser Token Block
parseUList = pmap UList (rep (parseListItem (exactly [Ch '-'])))

parseOList :: Parser Token Block
parseOList = pmap OList (rep (parseListItem (parseUInt `thn` exactly [Ch '.'])))

parseListItem :: Parser Token a -> Parser Token [Block]
parseListItem parseOrd input = do
  -- TODO: other languages (e.g. Japanese/Chinese) might use a full-width space
  --       what should we do then? :O
  (input1, line0) <- (parseOrd `thn2` utlNewlineInclusive) input
  (input2, iLines) <- pmap (fromMaybe []) (opt (rep parseIndented)) input1
  let minIndent = foldl min 0 (fst <$> iLines)
  let contents = line0 ++ concatMap (drop minIndent . snd) iLines
  (_, blocks) <- parseBlocks contents
  Just (input2, blocks)
  where
    -- parses a line if it is indented or blank
    -- returns the (indentWidth, tokens)
    utlNewlineInclusive :: Parser Token [Token]
    utlNewlineInclusive = pmap (uncurry (++)) (utl (exactly [Newline]))
    parseIndented :: Parser Token (Int, [Token])
    parseStuff =
      pmap
        length
        (rep (alt [exactly [Ch '\t'], exactly [Ch ' ']]))
        `thn` utlNewlineInclusive
    parseBlank =
      pmap
        (first (const (maxBound :: Int)))
        (opt (rep (exactly [Ch ' '])) `thn` exactly [Newline])
    parseIndented = alt [parseStuff, parseBlank]

parseBlocks :: Parser Token [Block]
parseBlocks =
  rep' (++) (alt [special, parseParagraph, fallback])
  where
    special =
      alt
        [ pmap (: []) parseLineBreak,
          pmap (: []) parseHeading,
          pmap (: []) parseCodeBlock,
          pmap (: []) parseUList,
          pmap (: []) parseOList,
          pmap (: []) parseQuote
        ]
    makeP input = Paragraph (snd (parseInline input))
    parseParagraph =
      pmap
        (\(para, blocks) -> makeP para : blocks)
        -- Once we've started a paragraph, we should keep going until we hit at
        -- least a newline
        (utl $ exactly [Newline] `thn2` special)
    fallback input = Just ([], [makeP input])

parseMarkdown :: String -> Maybe [Block]
parseMarkdown input = do
  (_, tokens) <- tokenize input -- TODO: this shouldn't fail...
  (tokens', blocks) <- parseBlocks tokens
  if null tokens' then Just blocks else Nothing

hasMath :: [Block] -> Bool
hasMath = any hasMathB

hasMathI :: Inline -> Bool
hasMathI (Index.MathBlock _) = True
hasMathI (Index.Equation _) = True
hasMathI _ = False

hasMathB :: Block -> Bool
hasMathB (Index.Paragraph is) = any hasMathI is
hasMathB (Index.Quote bs) = hasMath bs
hasMathB (Index.Heading _ is) = any hasMathI is
hasMathB _ = False

-- HTML ------------------------------------------------------------------------

-- Attributes, with a leading space
attributes :: [(String, String)] -> String
attributes [] = ""
attributes ((k, v) : xs) = " " ++ k ++ "=\"" ++ v ++ "\"" ++ attributes xs

escapeHtml :: String -> String
escapeHtml plaintext = esc' plaintext ""
  where
    esc' [] html = reverse html
    esc' (c : cs) html = esc' cs html'
      where
        pushStr s = reverse s ++ html
        html' = case c of
          '"' -> pushStr "&quot"
          '\'' -> pushStr "&apos"
          '&' -> pushStr "&amp;"
          '<' -> pushStr "&lt"
          '>' -> pushStr "&gt"
          _ -> c : html

tag :: String -> [(String, String)] -> String -> String
tag t attrs content =
  "<"
    ++ t
    ++ attributes attrs
    ++ ">"
    ++ content
    ++ "</"
    ++ t
    ++ ">"

tag' :: String -> [(String, String)] -> String
tag' t attrs = "<" ++ t ++ attributes attrs ++ ">"

inlinesToHtml :: [Inline] -> String
inlinesToHtml = concatMap inlineToHtml

inlineToHtml :: Inline -> String
-- We don't want to escape in this case, to allow the user to write HTML inline
inlineToHtml (Plaintext str) = str
-- But in the case of code, we do!
inlineToHtml (Code str) = tag "code" [] (escapeHtml str)
inlineToHtml (Italic xs) = tag "em" [] (inlinesToHtml xs)
inlineToHtml (Bold xs) = tag "strong" [] (inlinesToHtml xs)
inlineToHtml (Image altTxt src) = tag' "img" [("alt", altTxt), ("src", src)]
inlineToHtml (Link txt href) = tag "a" [("href", href)] txt
inlineToHtml (Equation formula) =
  tag "span" [("class", "tex-math")] ("\\( " ++ formula ++ " \\)")
inlineToHtml (MathBlock formula) =
  tag "div" [("class", "tex-math")] ("\\[ " ++ formula ++ " \\]")

blocksToHtml :: [Block] -> String
blocksToHtml = concatMap blockToHtml

blockToHtml :: Block -> String
blockToHtml (LineBreak n) = concat (replicate n "<br>")
blockToHtml (Paragraph xs) = tag "p" [] (inlinesToHtml xs)
blockToHtml (Heading n str) = tag ("h" ++ show (min 6 n)) [] (inlinesToHtml str)
blockToHtml (CodeBlock lang text) =
  tag "pre" [("lang", lang)] (tag "code" [] (escapeHtml text))
blockToHtml (Quote blocks) = tag "blockquote" [] (blocksToHtml blocks)
blockToHtml (UList blocks) = tag "ul" [] (listEntriesToHtml blocks)
blockToHtml (OList blocks) = tag "ol" [] (listEntriesToHtml blocks)

listEntriesToHtml :: [[Block]] -> String
listEntriesToHtml = concatMap (tag "li" [] . blocksToHtml) 
