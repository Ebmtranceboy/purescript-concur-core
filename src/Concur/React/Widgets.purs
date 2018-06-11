module Concur.React.Widgets where

import Prelude

import Concur.Core (Widget, withViewEvent, wrapViewEvent)
import Concur.React (HTML, NodeTag)
import Concur.React.DOM as CD
import Concur.React.Props (Props, mkProp)
import Control.Monad.Eff (Eff)
import Control.Monad.IOSync (IOSync, runIOSync')
import Control.MultiAlternative (orr)
import Data.Either (Either(..), either)
import Data.Function (applyFlipped)
import React (handle)
import React as R
import React.DOM as D
import React.DOM.Props (unsafeMkProps)
import React.DOM.Props as P

-- Combinator Widgets, at a higher level than those in Concur.React.DOM

-- BIG TODO: Use ShiftMap where ever possible

-- | Wrap a widget with a node that can have eventHandlers attached
elProps :: forall a. NodeTag -> Array (Props a) -> Widget HTML a -> Widget HTML a
elProps e props = wrapViewEvent \h v -> [e (map (mkProp h) props) v]

-- | Wrap some widgets with a node that can have eventHandlers attached
elProps' :: forall a. NodeTag -> Array (Props a) -> Array (Widget HTML a) -> Widget HTML a
elProps' e props = elProps e props <<< orr

-- Wrap a button around a widget
-- Returns a `Left unit on click events.
-- Or a `Right a` when the inner `Widget HTML a` ends.
wrapButton :: forall a. Array P.Props -> Widget HTML a -> Widget HTML (Either Unit a)
wrapButton props w = elEvent (\h -> P.onClick (const (runIOSync' (h (Left unit))))) D.button props (map Right w)

-- Like a wrapButton, but takes no props
wrapButton' :: forall a. Widget HTML a -> Widget HTML (Either Unit a)
wrapButton' = wrapButton []

-- Specialised button with only static children
displayButton :: Array P.Props -> (forall a. Widget HTML a) -> Widget HTML Unit
displayButton props d = either id id <$> wrapButton props d

-- Like a displayButton, but takes no props
displayButton' :: (forall a. Widget HTML a) -> Widget HTML Unit
displayButton' = displayButton []

-- Specialised text only button
textButton :: Array P.Props -> String -> Widget HTML Unit
textButton props label = displayButton props (CD.text label)

-- Like a textButton, but takes no props
textButton' :: String -> Widget HTML Unit
textButton' = textButton []

textArea :: Array P.Props -> String -> Widget HTML String
textArea props contents = withViewEvent (\h -> [D.textarea (props <> [P.value contents, P.onChange (runIOSync' <<< h <<< getEventTargetValueString)]) []])

textArea' :: String -> Widget HTML String
textArea' = textArea []

textInput :: Array P.Props -> String -> Widget HTML String
textInput props contents = withViewEvent (\h -> [D.input (props <> [P._type "text", P.defaultValue contents, P.onChange (runIOSync' <<< h <<< getEventTargetValueString)]) []])

textInput' :: String -> Widget HTML String
textInput' = textInput []

-- Can't use P.onKeyDown because that doesn't allow getting event information (i.e. value) in the handler
-- Also have to manually handle resetting the value of the checkbox on enter.
textInputEnter :: Array P.Props -> String -> Widget HTML String
textInputEnter props contents = withViewEvent (\h -> [D.input (props <> [P._type "text", P.defaultValue contents, onHandleEnter h]) []])
  where
   onHandleEnter :: (String -> IOSync Unit) -> P.Props
   onHandleEnter h = unsafeMkProps "onKeyDown" (handle f)
     where
       f e = when (getKeyboardEventKeyString e == "Enter") do
                 runIOSync' $ h $ getEventTargetValueString e
                 resetTargetValue "" e

textInputEnter' :: String -> Widget HTML String
textInputEnter' = textInputEnter []

checkbox :: Array P.Props -> Boolean -> Widget HTML Boolean
checkbox props checked = withViewEvent (\h -> [D.input (props <> [P._type "checkbox", P.checked checked, P.onChange (\_ -> runIOSync' (h (not checked)))]) []])

checkbox' :: Boolean -> Widget HTML Boolean
checkbox' = checkbox []

-- | Wrap an element with an arbitrary eventHandler over a widget
-- | Deprecated: Use elProps
elEvent :: forall a. ((a -> IOSync Unit) -> P.Props) -> NodeTag -> Array P.Props -> Widget HTML a -> Widget HTML a
elEvent evt = elEventMany [evt]

-- | Wrap an element with multiple arbitrary eventHandlers over a widget
-- | Deprecated: Use elProps
elEventMany :: forall a. Array ((a -> IOSync Unit) -> P.Props) -> NodeTag -> Array P.Props -> Widget HTML a -> Widget HTML a
elEventMany evts e props w = wrapViewEvent (\h v -> [e (props <> (map (applyFlipped h) evts)) v]) w

-- Wrap a div with key handlers around a widget
-- Returns a `Left unit on key events.
-- Or a `Right a` when the inner `Widget HTML a` ends.
wrapKeyHandler :: forall a. NodeTag -> Array P.Props -> (R.KeyboardEvent -> a) -> Widget HTML a -> Widget HTML a
wrapKeyHandler e props f w = wrapViewEvent (\h v -> [e (props <> [P.onKeyDown (\evt -> (runIOSync' (h (f evt))))]) v]) w

-- Specialised key handler widget with only static children
displayKeyHandler :: NodeTag -> Array P.Props -> (forall a. Widget HTML a) -> Widget HTML R.KeyboardEvent
displayKeyHandler e props w = wrapKeyHandler e props id w

-- Add a click handler around a widget
wrapClickHandler :: forall a. NodeTag -> Array P.Props -> (R.Event -> a) -> Widget HTML a -> Widget HTML a
wrapClickHandler e props f w = wrapViewEvent (\h v -> [e (props <> [P.onClick (\evt -> (runIOSync' (h (f evt))))]) v]) w

-- Specialised click handler widget with only static children
displayClickHandler :: NodeTag -> Array P.Props -> (forall a. Widget HTML a) -> Widget HTML R.Event
displayClickHandler e props w = wrapClickHandler e props id w

-- Add a double click handler around a widget
wrapDoubleClickHandler :: forall a. NodeTag -> Array P.Props -> (R.Event -> a) -> Widget HTML a -> Widget HTML a
wrapDoubleClickHandler e props f w = wrapViewEvent (\h v -> [e (props <> [P.onDoubleClick (\evt -> (runIOSync' (h (f evt))))]) v]) w

-- Specialised double click handler widget with only static children
displayDoubleClickHandler :: NodeTag -> Array P.Props -> (forall a. Widget HTML a) -> Widget HTML R.Event
displayDoubleClickHandler e props w = wrapDoubleClickHandler e props id w

-- Generic function to get info out of events
-- TODO: Move these to some other place
foreign import getEventTargetValueString :: R.Event -> String
foreign import getKeyboardEventKeyString :: R.Event -> String
foreign import resetTargetValue :: forall eff. String -> R.Event -> Eff eff Unit
