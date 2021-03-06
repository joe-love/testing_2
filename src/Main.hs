{-# LANGUAGE DeriveDataTypeable #-}

module Main where

import Control.Monad (filterM)
import Data.Word (Word8)
import Data.Char (isAscii, isPrint)
import System.Console.CmdArgs
  (Data, Typeable, args, cmdArgs, def, help, program, summary, typ, (&=))
import System.Directory (doesFileExist)
import System.Random (randomRIO)
import Text.Wrap (wrapText, WrapSettings(..))
import qualified Data.Text as T

import UI (run)

data Config = Config
  { height :: Int
  , width :: Int
  , tab :: Int
  , files :: [FilePath]
  , fg_empty :: Word8
  , fg_error :: Word8
  } deriving (Show, Data, Typeable)

toAscii :: Int -> String -> String
toAscii tabWidth = concatMap toAscii'
  where
    toAscii' c
      | c == '\t' = replicate tabWidth ' '
      | c == '‘' || c == '’' = "'"
      | c == '“' || c == '”' = "\""
      | c == '–' || c == '—' = "-"
      | c == '…' = "..."
      | isAscii c && (isPrint c || c == '\n') = [c]
      | otherwise = ""

trimEmptyLines :: String -> String
trimEmptyLines = (++ "\n") . f . f
  where
    f = reverse . dropWhile (== '\n')

config :: Config
config = Config
  { height = 20 &= typ "LINES" &=
    help "The maximum number of lines to sample (default: 20)"
  , width = 80 &= typ "CHARS" &=
    help "The width at which to wrap lines (default: 80)"
  , tab = 4 &= typ "SIZE" &=
    help "The size of a tab in spaces (default: 4)"
  , fg_empty = 8 &= typ "COLOUR" &=
    help "The ISO colour code for empty (not yet typed) characters (default: 8)"
  , fg_error = 1 &= typ "COLOUR" &=
    help "The ISO colour code for errors (default: 1)"
  , files = def &= args &= typ "FILES"
  }
  &= summary "Gotta Go Fast 0.1.4.0"
  &= help "Practice typing and measure your WPM and accuracy"
  &= program "gotta-go-fast"

sample :: Config -> String -> IO String
sample c file = do
  r <- randomRIO (0, max 0 $ length (lines ascii) - height c)
  return $ trimEmptyLines $ chop $ wrap $ chop $ unlines $ drop r $ lines ascii
    where
      ascii = toAscii (tab c) file
      chop = unlines . take (height c) . lines
      wrap = T.unpack . wrapText wrapSettings (width c) . T.pack
      wrapSettings = WrapSettings
        { preserveIndentation = True
        , breakLongWords = True
        }

main :: IO ()
main = do
  c <- cmdArgs config
  fs <- filterM doesFileExist $ files c
  case fs of
    [] -> putStrLn "Requires at least one file path"
    _ -> do
      r <- randomRIO (0, length fs - 1)
      file <- readFile $ fs !! r
      sampled <- sample c file
      run (fg_empty c) (fg_error c) sampled
