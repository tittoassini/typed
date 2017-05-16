{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric  #-}
module Data.Typed.Type.Float32(IEEE_754_binary32(..)) where

import           Data.Model
import           Data.Typed.Type.Bits8
import           Data.Typed.Type.Bits23
import           Data.Typed.Type.Words

-- |An IEEE-754 Big Endian 32 bits Float
data IEEE_754_binary32 =
       IEEE_754_binary32
         { sign     :: Sign
         , exponent :: MostSignificantFirst Bits8
         , fraction :: MostSignificantFirst Bits23
         }
  deriving (Eq, Ord, Show, Generic, Model)


-- Low Endian
-- data IEEE_754_binary32_LE =
--        IEEE_754_binary32_LE
--          { fractionLE :: LeastSignificantFirst Bits23
--          , exponentLE :: LeastSignificantFirst Bits8
--          , signLE     :: Sign
--          }
-- or data IEEE_754_binary32_LE = IEEE_754_binary32 Word64
