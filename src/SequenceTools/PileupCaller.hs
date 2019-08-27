module SequenceTools.PileupCaller (callToDosage, Call(..), callGenotypeFromPileup,
    callMajorityAllele, findMajorityAlleles, callRandomAllele,
    callRandomDiploid, CallingMode(..)) where

import Data.List (sortOn, group, sort)
import SequenceTools.Utils (sampleWithoutReplacement)
-- |A datatype to represent a single genotype call
data Call = HaploidCall Char | DiploidCall Char Char | MissingCall deriving (Show, Eq)

-- |A datatype to specify the calling mode
data CallingMode = MajorityCalling Bool | RandomCalling | RandomDiploidCalling

-- |a function to turn a call into the dosage of non-reference alleles
callToDosage :: Char -> Char -> Call -> Maybe Int
callToDosage refA altA call = case call of
    HaploidCall a | a == refA -> Just 0
                  | a == altA -> Just 1
                  | otherwise -> Nothing
    DiploidCall a1 a2 | (a1, a2) == (refA, refA) -> Just 0
                      | (a1, a2) == (refA, altA) -> Just 1
                      | (a1, a2) == (altA, refA) -> Just 1
                      | (a1, a2) == (altA, altA) -> Just 2
                      | otherwise                -> Nothing
    MissingCall -> Nothing

-- |Make a call from alleles 
callGenotypeFromPileup :: CallingMode -> Int -> String -> IO Call
callGenotypeFromPileup mode minDepth alleles =
    if length alleles < minDepth then return MissingCall else
        case mode of
            MajorityCalling withDownsampling -> callMajorityAllele withDownsampling minDepth alleles
            RandomCalling -> callRandomAllele alleles
            RandomDiploidCalling -> callRandomDiploid alleles

-- |Sample the majority allele, or one of the majority alleles
callMajorityAllele :: Bool -> Int-> String -> IO Call
callMajorityAllele withDownsampling minDepth alleles = do
    maybeAlleles <- if withDownsampling
        then sampleWithoutReplacement alleles minDepth
        else return (Just alleles)
    case maybeAlleles of
        Nothing -> return MissingCall
        Just alleles' -> do
            a <- case findMajorityAlleles alleles' of
                [] -> error "should not happen"
                [a'] -> return a'
                listA -> do
                    r <- sampleWithoutReplacement listA 1
                    case r of
                        Just [r'] -> return r'
                        _ -> error "should not happen"
            return $ HaploidCall a

-- |Find the majority allele(s)
findMajorityAlleles :: String -> [Char]
findMajorityAlleles alleles =
    let groupedAlleles = sortOn fst [(length g, head g) | g <- group . sort $ alleles]
        majorityCount = fst . last $ groupedAlleles
    in  [a | (n, a) <- groupedAlleles, n == majorityCount]

-- |call a random allele
callRandomAllele :: String -> IO Call
callRandomAllele alleles = do
    res <- sampleWithoutReplacement alleles 1
    case res of
        Nothing -> return MissingCall
        Just [a] -> return $ HaploidCall a
        _ -> error "should not happen"

-- |call two random alleles
callRandomDiploid :: String -> IO Call
callRandomDiploid alleles = do
    res <- sampleWithoutReplacement alleles 2
    case res of
        Nothing -> return MissingCall
        Just [a1, a2] -> return $ DiploidCall a1 a2
        _ -> error "should not happen"