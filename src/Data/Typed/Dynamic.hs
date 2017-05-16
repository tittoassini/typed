{-# LANGUAGE ScopedTypeVariables #-}

-- |Dynamical decoding of serialised typed values
module Data.Typed.Dynamic(
  decodeAbsTypeModel
  ,typeDecoder
  ,typeDecoderMap
  ,MapTypeDecoder
  ) where

import qualified Data.ByteString      as B
import           Data.Flat
import qualified Data.ListLike.String as S
import qualified Data.Map             as M
import           Data.Model
import           Data.Typed.Transform
import           Data.Typed.Types

-- | Decode a Flat encoded value with a known type model to the corresponding Value
decodeAbsTypeModel :: AbsTypeModel -> B.ByteString -> Decoded Value
decodeAbsTypeModel = unflatWith . typeDecoder

-- |Returns a decoder for the type defined by the given model
typeDecoder :: AbsTypeModel -> Get Value
typeDecoder tm = solve (typeName tm) (typeDecoderMap tm)

-- |A mapping between references to absolute types and the corresponding decoder
type MapTypeDecoder = M.Map (Type AbsRef) (Get Value)

-- |Returns decoders for all types in the given model
typeDecoderMap :: AbsTypeModel -> MapTypeDecoder
typeDecoderMap tm =
  let denv = M.mapWithKey (\t ct -> conDecoder denv t [] ct) (typeTree tm)
  in denv

conDecoder :: (S.StringLike name) => MapTypeDecoder -> AbsType -> [Bool] -> ConTree name AbsRef -> Get Value
conDecoder env t bs (ConTree l r) = do
  tag :: Bool <- decode
  conDecoder env t (tag:bs) (if tag then r else l)

conDecoder env t bs (Con cn cs) = Value t (S.toString cn) (reverse bs) <$> mapM (`solve` env) (fieldsTypes cs)


