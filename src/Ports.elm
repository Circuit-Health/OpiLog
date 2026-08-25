port module Ports exposing (..)

import Json.Encode as Encode

port saveBolus : Encode.Value -> Cmd msg
port savePatch : Encode.Value -> Cmd msg
port removePatch : String -> Cmd msg
port requestInitialData : () -> Cmd msg

port onInitialDataLoaded : (Encode.Value -> msg) -> Sub msg