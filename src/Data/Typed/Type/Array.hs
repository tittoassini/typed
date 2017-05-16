{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric  #-}
module Data.Typed.Type.Array(Array,Bytes) where
import           Data.Flat.Filler
import           Data.Model
import           Data.Typed.Type.Generate
import qualified Data.Typed.Type.Words    as Z

{-|An Array.

@
Array a  = A0
         | A1 a (Array a)
         | A2 a a (Array a)
         ...
         | A255 a ... (Array a)
@
-}
data Array a
instance Model a => Model (Array a) where envType = useCT arrayCT

-- |A byte-aligned byte array
data Bytes = Bytes (PreAligned (Array Z.Word8)) deriving (Generic,Model)

instance Model Filler
instance Model a => Model (PreAligned a)
