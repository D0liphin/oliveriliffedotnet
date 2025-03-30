module Main where

import Article (makeBlog)

main :: IO ()
main = do
  _ <- makeBlog "./blog"
  return ()