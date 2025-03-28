module Main where

import Md (parseMarkdown, blocksToHtml)
import Data.Maybe (fromJust)

main :: IO ()
main = do
  input <- readFile "testing.md"
  let html = blocksToHtml $ fromJust $ parseMarkdown input
  writeFile "testing.html" html