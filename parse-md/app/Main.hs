module Main where

import Config (parseConfig)
import Data.Maybe (fromJust)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import Index (blocksToHtml, parseMarkdown)

main :: IO ()
main = do
  toml <- Text.readFile "./test-article/config.toml"
  let ast = parseConfig toml
  print ast
  return ()

-- input <- readFile "testing.md"
-- let ast = fromJust $ parseMarkdown input
-- print ast
-- let html = blocksToHtml ast
-- writeFile "testing.html" html