
Haskell implementation of canonical, language independent data types.

### How To Use It For Fun and Profit

With `typed` you can derive and manipulate canonical description of (a subset) of Haskell data types.

This can be used, for example:

* in combination with a serialisation library to provide type-safe deserialisation
* for data exchange across different programming languages and software systems
* for long term data preservation

#### Canonical Models of Haskell Data Types

For a data type to have a canonical representation, it has to implement the `Model` type class.

Instances for a few common data types (Bool, Maybe, Tuples, Lists, Ints, Words, String, Text ..) are already defined (in `Data.Typed.Instances`) and there is `Generics` based support to automatically derive additional instances.

Let's see some code.

We need a couple of GHC extensions:

```haskell
{-# LANGUAGE DeriveGeneric, DeriveAnyClass, NoMonomorphismRestriction #-}
```

Import the library:

```haskell
import Data.Typed
```

We will need this too, for the examples.

```haskell
import Data.Word
```

We use `absTypeModel` to get the canonical type of `Maybe Bool` and `pPrint` to print is nicely:

```haskell
prt = pPrint . CompactPretty
```

```haskell
prt $ absTypeModel (Proxy :: Proxy (Maybe Bool))
-> S793d1387f115 S81d428306f1d -> Maybe Bool
-> 
-> Data Types:
-> S793d1387f115 ->  Maybe a ≡   Nothing
->                             | Just a
-> S81d428306f1d ->  Bool ≡   False
->                          | True
```


We can see how the data types `Maybe` and `Bool` have been assigned unique canonical identifiers and how the type `Maybe Bool` is accordingly represented.

Contrary to Haskell, `typed` has no 'magic' built-in types so even something as basic as a `Char` or a `Word` have to be defined explicitly.

For example, a `Word7` (an unsigned integer of 7 bits length) is defined as an explicit enumeration of all the 128 different values that can fit in 7 bits:

```haskell
prt $ absTypeModel (Proxy :: Proxy Word7)
-> Sb1f0655240ab -> Word7
-> 
-> Data Types:
-> Sb1f0655240ab ->  Word7 ≡   V0
->                           | V1
-> ...
->                           | V123
->                           | V124
->                           | V125
->                           | V126
->                           | V127
```


A `Word32` can be defined as a `NonEmptyList` list of `Word7`s (a definition equivalent to the [Base 128 Varints encoding](https://developers.google.com/protocol-buffers/docs/encoding#varints)).

```haskell
prt $ absTypeModel (Proxy :: Proxy Word32)
-> S37c45c448792 -> Word32
-> 
-> Data Types:
-> S081ae65ed81f ->  MostSignificantFirst a ≡ MostSignificantFirst a
-> S37c45c448792 ->  Word32 ≡ Word32 Word
-> ...
->                           | V123
->                           | V124
->                           | V125
->                           | V126
->                           | V127
```


And finally a `Char` can be defined as a tagged `Word32`:

```haskell
prt $ absTypeModel (Proxy :: Proxy Char)
-> S07755d0e181d -> Char
-> 
-> Data Types:
-> S07755d0e181d ->  Char ≡ Char Word32
-> S081ae65ed81f ->  MostSignificantFirst a ≡ MostSignificantFirst a
-> ...
->                           | V123
->                           | V124
->                           | V125
->                           | V126
->                           | V127
```


Most common haskell data types can be automatically mapped to the equivalent canonical data type.

There are however a couple of restrictions: data types definitions cannot be mutually recursive and type variables must be of kind *.

So for example, these won't work:

```haskell
-- BAD: f has higher kind
data Free = Impure (f (Free f a)) | Pure a

-- BAD: mutually recursive
data Forest a = Nil | Cons (Tree a) (Forest a)
data Tree a = Empty | Node a (Forest a)
```

So now that we have canonical types, what about some practical applications?

#### Safe Deserialisation

To illustrate the problem, consider the two following data types:

The [Cinque Terre](https://en.wikipedia.org/wiki/Cinque_Terre) villages:

```haskell
data CinqueTerre = Monterosso | Vernazza | Corniglia | Manarola | RioMaggiore deriving (Show,Generic,Flat,Model)
```

The traditional Chinese directions:

```haskell
data Direction = North | South | Center | East | West deriving (Show,Generic,Flat,Model)
```

Though their meaning is obviously different they share the same syntactical structure (simple enumerations of 5 values) and most binary serialisation libraries won't be able to distinguish between the two.

To demonstrate this, let's serialise `Center` and `Corniglia`, the third value of each enumeration using the `flat` library.

```haskell
pPrint $ flatStrict Center
-> [129]
```


```haskell
pPrint $ flatStrict Corniglia
-> [129]
```


As you can see they have the same binary representation.

We have used the `flat` binary serialisation as it is already a dependency of `typed` (and automatically imported by `Data.Typed`) but the same principle apply to other serialisation libraries (`binary`, `cereal` ..).

Let's go full circle, using `unflat` to decode the value :

```haskell
decoded = unflat . flatStrict
```

```haskell
decoded Center :: Decoded Direction
-> Right Center
```


One more time:

```haskell
decoded Center :: Decoded CinqueTerre
-> Right Corniglia
```


Oops, that's not quite right.

We got our types crossed, `Center` was read back as `Corniglia`, a `Direction` was interpreted as one of the `CinqueTerre`.

To fix this, we convert the value to a `TypedValue`, a value combined with its canonical type:

```haskell
pPrint $ typedValue Center
-> Center :: Sc27a1135e194
```


TypedValues can be serialised as any other value:

```haskell
pPrint <$> (decoded $ typedValue Center :: Decoded (TypedValue Direction))
-> Right Center :: Sc27a1135e194
```


And just as before, we can get things wrong:

```haskell
pPrint <$> (decoded $ typedValue Center :: Decoded (TypedValue CinqueTerre))
-> Right Corniglia :: Sc27a1135e194
```


However this time is obvious that the value is inconsistent with its type, as the `CinqueTerre` data type has a different unique code:

```haskell
pPrint $ absTypeModel (Proxy :: Proxy CinqueTerre)
-> Sabe8a4afc323 -> CinqueTerre
-> 
-> Data Types:
-> Sabe8a4afc323 ->  CinqueTerre ≡   Monterosso
->                                 | Vernazza
->                                 | Corniglia
->                                 | Manarola
->                                 | RioMaggiore
```


We can automate this check, with `untypedValue`:

This is ok:

```haskell
untypedValue . decoded . typedValue $ Center :: TypedDecoded Direction
-> Right Center
```


And this is wrong:

```haskell
untypedValue . decoded . typedValue $ Center :: TypedDecoded CinqueTerre
-> Left (WrongType {expectedType = TypeCon (AbsRef (SHA3_256_6 171 232 164 175 195 35)), actualType = TypeCon (AbsRef (SHA3_256_6 194 122 17 53 225 148))})
```


### Data Exchange

For an example of using canonical data types as a data exchange mechanism see [top](https://github.com/tittoassini/top), the Type Oriented Protocol.

<!--
### Long Term Data Preservation

For an example of using canonical data types as a long term data preservation mechanism see [timeless](https://github.com/tittoassini/timeless).

Inspect the data to figure out its type dynamically

So far so good but what if we lose the definitions of our data types?

Two ways:
-- save the full canonical definition of the data with the data itself or
-- save the def in the cloud so that it can be shared

Better save them for posterity:

sv = saveTypeIn theCloud (Couple One Tre)

The type has been saved, with all its dependencies.
TypeApp (TypeApp (TypeCon (CRC16 91 93)) (TypeCon (CRC16 79 130))) (TypeCon (CRC16 65 167))

Now that they are safe in the Cloud we can happily burn our code
in the knowledge that when we are presented with a binary of unknown type
we can always recover the full definition of our data.

PUT BACK dt = e2 >>= recoverTypeFrom theCloud
What if we have no idea of what is the type

instance (Flat a , Flat b) => Flat (CoupleB a b)

t = ed False >> ed Tre >> ed (Couple (CoupleB True Uno One) Three)
ed = pp . unflatDynamically . flat . typedValue


We can now use it to define a hard-wired decoder

Or use a dynamic decder to directly show the value.

The final system will also keep track of the documentation that comes with the types to give you a fully human understandable description of the data.
-->

### Installation

It is not yet on [hackage](https://hackage.haskell.org/) but you can use it in your [stack](https://docs.haskellstack.org/en/stable/README/) projects by adding in the `stack.yaml` file, under the `packages` section:

````
- location:
   git: https://github.com/tittoassini/typed
   commit: 
  extra-dep: true

````

### Compatibility

Tested with [ghc](https://www.haskell.org/ghc/) 7.10.3 and 8.0.1 and [ghcjs](https://github.com/ghcjs/ghcjs).

### Acknowledgements
 Contains the following JavaScript library:

 js-sha3 v0.5.1 https://github.com/emn178/js-sha3

 Copyright 2015, emn178@gmail.com

 Licensed under the MIT license:http://www.opensource.org/licenses/MIT

### Known Bugs and Infelicities

* The unique codes generated for the data types are not yet final and might change in the final version.
* Instances for parametric data types have to be declared separately (won't work in `deriving`)

