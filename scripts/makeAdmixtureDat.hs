#!/usr/bin/env stack
-- stack --resolver lts-6.4 --install-ghc runghc --package turtle 

{-# LANGUAGE OverloadedStrings #-}

import Control.Foldl (list)
import Control.Monad (forM_)
import Data.List (sortOn, groupBy)
import qualified Data.Text as T
import qualified Data.Text.IO as T
import Prelude hiding (FilePath)
import Turtle

main = do
    (admixtureF, popF, popGroupF) <- options "prepare Admixture data for DataGraph" 
                                               optParser
    printData admixtureF popF popGroupF
  where
    optParser = (,,) <$> argPath "admixtureFile" "Input Admixture file" <*>
                          argPath "popFile" "Input *.ind file" <*>
                          argPath "popGroupFile" "PopGroup file"

printData admixtureF popF popGroupF = do
    popGroupDat <- readPopGroupDat popGroupF
    admixtureDat <- fold (readAdmixtureDat popGroupDat admixtureF popF) list
    let (_, _, _, vals) = head admixtureDat
        k = length vals
        sortedDat = sortOn (\(_, _, pg, _) -> pg) . sortOn (\(_, p, _, _) -> p) $ admixtureDat
        legendedDat = putLegend sortedDat
    echo . T.intercalate "\t" $ ["Sample", "Pop", "PopGroup", "Label"] ++
                                [format ("Q"%d) i | i <- [1..12]]
    forM_ legendedDat $ \group -> do
        forM_ group $ \(sample, pop, popGroup, legend, vals) -> do
            let vals' = vals ++ replicate (12 - length vals) 0.0
            echo . T.intercalate "\t" $ [sample, pop, popGroup, legend] ++ map (format g) vals'
        echo ""

readPopGroupDat :: FilePath -> IO [(Text, Text)]
readPopGroupDat popGroupF = do
    l <- fold (input popGroupF) list
    return [(p, pG) | [p, pG] <- map (cut (some space) . T.strip) l]

readAdmixtureDat :: [(Text, Text)] -> FilePath -> FilePath -> Shell (Text, Text, Text, [Double])
readAdmixtureDat popGroupDat admixtureF popF = do
    (admixtureL, indL) <- paste (input admixtureF) (input popF)
    let vals = map (read . T.unpack) . cut (some space) $ admixtureL
        [sample, _, pop] = cut (some space) . T.strip $ indL
    Just popGroup <- return $ pop `lookup` popGroupDat
    return (sample, pop, popGroup, vals)

putLegend :: [(Text, Text, Text, [Double])] -> [[(Text, Text, Text, Text, [Double])]]
putLegend admixtureDat = do
    group <- groups
    let l = length group
        (_, pop, _, _) = head group
        labels = [if i == l `div` 2 then pop else "" | i <- [0..(l - 1)]]
    return [(s, p, pg, l, v) | ((s, p, pg, v), l) <- zip group labels]
  where
    groups = groupBy (\(_, pop1, _, _) (_, pop2, _, _) -> pop1 == pop2) admixtureDat
        