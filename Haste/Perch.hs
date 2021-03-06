-----------------------------------------------------------------------------
--
-- Module      :  Builder
-- Copyright   :
-- License     :  BSD3
--
-- Maintainer  :  agocorona@gmail.com
-- Stability   :  experimental
-- Portability :
--
-- | Monad and Monoid instances for a builder that hang DOM elements from the
-- current parent element. It uses Haste.DOM from the haste-compiler
--
-----------------------------------------------------------------------------
{-#LANGUAGE TypeSynonymInstances, FlexibleInstances
            , OverloadedStrings, DeriveDataTypeable, UndecidableInstances
            , OverlappingInstances #-}
module Haste.Perch where
import Data.Typeable
import Haste
import Haste.DOM
import Haste.Foreign(ffi)
import Data.Maybe
import Data.Monoid
import Unsafe.Coerce

newtype PerchM a= Perch{build :: Elem -> IO Elem} deriving Typeable

type Perch = PerchM ()

instance Monoid (PerchM a) where
    mappend mx my= Perch $ \e -> do
         build mx e
         build my e
         return e
    mempty  = Perch return

instance Monad PerchM where
   (>>) x y= mappend (unsafeCoerce x) y
   (>>=) = error "bind (>>=) invocation creating DOM elements"
   return  = mempty



class ToElem a where
  toElem :: a -> Perch

instance ToElem String where
   toElem s= Perch $ \e ->do
        e' <- newTextElem s
        addChild e' e
        return e'

instance Show a => ToElem a where toElem = toElem . show

instance ToElem (PerchM a) where toElem e = unsafeCoerce e

attr tag (n, v)=Perch $ \e -> do
        tag' <- build tag e
        setAttr tag' n v
        return tag'

nelem s= Perch $ \e ->do
        e' <- newElem s
        addChild e' e
        return e'

child :: ToElem a => Perch -> a -> Perch
child me ch= Perch $ \e' -> do
        e <- build me e'
        let t = toElem ch
        r <- build t e
        return e

addEvent :: Perch -> Event IO b -> IO () -> Perch
addEvent be event action= Perch $ \e -> do
     e' <- build be e
     has <- getAttr e' "hasevent"
     case has of
       "true" -> return e'
       _ -> do
        onEvent e' event $ unsafeCoerce $ action -- >> focus e
        setAttr e' "hasevent" "true"
        return e'

elemsByTagName :: String -> IO [Elem]
elemsByTagName = ffi "(function(s){document.getElementsByTagName(s)})"

parent :: Elem -> IO Elem
parent= ffi "(function(e){return e.parentNode;})"

br= nelem "br"


div cont=  nelem "div" `child`  cont

p cont = nelem "p" `child` cont

b cont = nelem "b" `child` cont


(!) pe atrib = \e ->  pe e `attr` atrib

atr n v= (n,v)

