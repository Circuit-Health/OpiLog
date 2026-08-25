module Main exposing (main)

import Browser
import Calculations exposing (computeSummary)
import Html exposing (..)
import Html.Attributes exposing (class, style)
import Html.Events exposing (onClick)
import Json.Decode as Decode
import Json.Encode as Encode
import Ports
import String exposing (fromFloat)
import Time
import Types exposing (BolusEntry, MetricsSummary, OpioidDrug, OpioidRoute(..), PatchEntry)

type alias Model =
    { currentTime : Time.Posix
    , availableDrugs : List OpioidDrug
    , boluses : List BolusEntry
    , patches : List PatchEntry
    , currentPatch : Maybe PatchEntry
    }

type Msg
    = Tick Time.Posix
    | InitialDataReceived Encode.Value
    | LogPresetBolus OpioidDrug Float Bool
    | LogPresetPatch OpioidDrug Float
    | RemoveActivePatch String

availableCatalog : List OpioidDrug
availableCatalog =
    [ { id = "oxy-ir", name = "Oxycodone IR", route = Oral, conversionFactor = 1.5, defaultWearHours = 0 }
    , { id = "hyd-ir", name = "Hydromorphone", route = Oral, conversionFactor = 4.0, defaultWearHours = 0 }
    , { id = "tap-ir", name = "Tapentadol IR", route = Oral, conversionFactor = 0.3, defaultWearHours = 0 }
    , { id = "norspan", name = "Buprenorphine Patch (Norspan)", route = TransdermalPatch, conversionFactor = 2.0, defaultWearHours = 168 }
    , { id = "durogesic", name = "Fentanyl Patch (Durogesic)", route = TransdermalPatch, conversionFactor = 3.0, defaultWearHours = 72 }
    ]

init : () -> ( Model, Cmd Msg )
init _ =
    ( { currentTime = Time.millisToPosix 0
      , availableDrugs = availableCatalog
      , boluses = []
      , patches = []
      , currentPatch = Nothing
      }
    , Ports.requestInitialData ()
    )

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Tick time ->
            ( { model | currentTime = time }, Cmd.none )

        InitialDataReceived json ->
            case decodeDatabasePayload json of
                Ok ( loadedBoluses, loadedPatches ) ->
                    let
                        active =
                            List.filter (\p -> p.removedAtMs == Nothing) loadedPatches
                                |> List.head
                    in
                    ( { model
                        | boluses = loadedBoluses
                        , patches = loadedPatches
                        , currentPatch = active
                      }
                    , Cmd.none
                    )

                Err _ ->
                    ( model, Cmd.none )

        LogPresetBolus drug doseMg isPrn ->
            let
                nowMs =
                    Time.posixToMillis model.currentTime

                calculatedOmedd =
                    Calculations.bolusToOmedd doseMg drug.conversionFactor

                newEntry : BolusEntry
                newEntry =
                    { id = "bolus-" ++ String.fromInt nowMs
                    , drugId = drug.id
                    , drugName = drug.name
                    , timestampMs = nowMs
                    , doseMg = doseMg
                    , isPrn = isPrn
                    , omedd = calculatedOmedd
                    }

                updatedList =
                    newEntry :: model.boluses
            in
            ( { model | boluses = updatedList }
            , Ports.saveBolus (encodeBolus newEntry)
            )

        LogPresetPatch drug ratedMcg ->
            let
                nowMs =
                    Time.posixToMillis model.currentTime

                omeddHr =
                    Calculations.patchToOmeddPerHour ratedMcg drug.conversionFactor

                newPatch : PatchEntry
                newPatch =
                    { id = "patch-" ++ String.fromInt nowMs
                    , drugId = drug.id
                    , drugName = drug.name
                    , appliedAtMs = nowMs
                    , removedAtMs = Nothing
                    , ratedDeliveryRateMcg = ratedMcg
                    , omeddPerHour = omeddHr
                    }
            in
            ( { model
                | patches = newPatch :: model.patches
                , currentPatch = Just newPatch
              }
            , Ports.savePatch (encodePatch newPatch)
            )

        RemoveActivePatch patchId ->
            let
                nowMs =
                    Time.posixToMillis model.currentTime

                updatedPatches =
                    List.map
                        (\p ->
                            if p.id == patchId then
                                { p | removedAtMs = Just nowMs }

                            else
                                p
                        )
                        model.patches
            in
            ( { model
                | patches = updatedPatches
                , currentPatch = Nothing
              }
            , Ports.removePatch patchId
            )

-- Decoders & Encoders

decodeDatabasePayload : Decode.Value -> Result Decode.Error ( List BolusEntry, List PatchEntry )
decodeDatabasePayload =
    Decode.decodeValue
        (Decode.map2 Tuple.pair
            (Decode.field "boluses" (Decode.list decodeBolus))
            (Decode.field "patches" (Decode.list decodePatch))
        )

decodeBolus : Decode.Decoder BolusEntry
decodeBolus =
    Decode.map7 BolusEntry
        (Decode.field "id" Decode.string)
        (Decode.field "drugId" Decode.string)
        (Decode.field "drugName" Decode.string)
        (Decode.field "timestampMs" Decode.int)
        (Decode.field "doseMg" Decode.float)
        (Decode.field "isPrn" Decode.bool)
        (Decode.field "omedd" Decode.float)

decodePatch : Decode.Decoder PatchEntry
decodePatch =
    Decode.map7 PatchEntry
        (Decode.field "id" Decode.string)
        (Decode.field "drugId" Decode.string)
        (Decode.field "drugName" Decode.string)
        (Decode.field "appliedAtMs" Decode.int)
        (Decode.field "removedAtMs" (Decode.nullable Decode.int))
        (Decode.field "ratedDeliveryRateMcg" Decode.float)
        (Decode.field "omeddPerHour" Decode.float)

encodeBolus : BolusEntry -> Encode.Value
encodeBolus b =
    Encode.object
        [ ( "id", Encode.string b.id )
        , ( "drugId", Encode.string b.drugId )
        , ( "drugName", Encode.string b.drugName )
        , ( "timestampMs", Encode.int b.timestampMs )
        , ( "doseMg", Encode.float b.doseMg )
        , ( "isPrn", Encode.bool b.isPrn )
        , ( "omedd", Encode.float b.omedd )
        ]

encodePatch : PatchEntry -> Encode.Value
encodePatch p =
    Encode.object
        [ ( "id", Encode.string p.id )
        , ( "drugId", Encode.string p.drugId )
        , ( "drugName", Encode.string p.drugName )
        , ( "appliedAtMs", Encode.int p.appliedAtMs )
        , ( "removedAtMs"
          , case p.removedAtMs of
                Just t ->
                    Encode.int t

                Nothing ->
                    Encode.null
          )
        , ( "ratedDeliveryRateMcg", Encode.float p.ratedDeliveryRateMcg )
        , ( "omeddPerHour", Encode.float p.omeddPerHour )
        ]

-- View

view : Model -> Html Msg
view model =
    let
        nowMs =
            Time.posixToMillis model.currentTime

        summary =
            computeSummary nowMs model.boluses model.patches
    in
    div [ class "container" ]
        [ h2 [ style "margin-bottom" "12px", style "letter-spacing" "-0.02em" ] [ text "OpiLog Exposure Diary" ]
        , p [ style "color" "var(--text-muted)", style "font-size" "0.85rem", style "margin-bottom" "16px" ]
            [ text "Descriptive daily oral Morphine Equivalent exposure for GP review." ]

        -- Metric Windows Card
        , div [ class "card" ]
            [ h3 [ style "font-size" "0.95rem", style "color" "var(--text-muted)" ] [ text "Calculated Exposure Summary" ]
            , div [ class "stat-grid" ]
                [ div [ class "stat-box" ]
                    [ div [ class "stat-val" ] [ text (roundOneDec summary.window1Day.totalOmedd ++ " mg") ]
                    , div [ class "stat-label" ] [ text "Last 24h Total" ]
                    ]
                , div [ class "stat-box" ]
                    [ div [ class "stat-val" ] [ text (roundOneDec summary.window3Day.dailyAverage ++ " mg/d") ]
                    , div [ class "stat-label" ] [ text "3-Day Average" ]
                    ]
                , div [ class "stat-box" ]
                    [ div [ class "stat-val" ] [ text (roundOneDec summary.window7Day.dailyAverage ++ " mg/d") ]
                    , div [ class "stat-label" ] [ text "7-Day Average" ]
                    ]
                ]
            ]

        -- Active Patch Status Card
        , div [ class "card" ]
            [ h3 [ style "font-size" "0.95rem", style "color" "var(--text-muted)" ] [ text "Active Transdermal Patch" ]
            , case model.currentPatch of
                Just active ->
                    div [ style "margin-top" "8px" ]
                        [ p [ style "font-weight" "600" ] [ text (active.drugName ++ " (" ++ fromFloat active.ratedDeliveryRateMcg ++ " mcg/hr)") ]
                        , p [ style "font-size" "0.8rem", style "color" "var(--text-muted)" ]
                            [ text ("Continuous delivery: " ++ roundOneDec (active.omeddPerHour * 24.0) ++ " mg/day oMEDD") ]
                        , div [ class "btn-row" ]
                            [ button [ onClick (RemoveActivePatch active.id), style "background" "var(--danger)" ] [ text "Remove / Replaced Patch" ] ]
                        ]

                Nothing ->
                    div [ style "margin-top" "8px" ]
                        [ p [ style "font-size" "0.85rem", style "color" "var(--text-muted)" ] [ text "No patch currently active." ]
                        , div [ class "btn-row" ]
                            (List.filter (\d -> d.route == TransdermalPatch) model.availableDrugs
                                |> List.map
                                    (\d ->
                                        button [ class "patch", onClick (LogPresetPatch d 10.0) ]
                                            [ text ("Apply " ++ d.name ++ " 10mcg") ]
                                    )
                            )
                        ]
            ]

        -- Quick Log PRN / Regular Card
        , div [ class "card" ]
            [ h3 [ style "font-size" "0.95rem", style "color" "var(--text-muted)" ] [ text "Quick Dose Logging" ]
            , div [ class "btn-row" ]
                [ button [ class "prn", onClick (logDrug model "oxy-ir" 5.0 True) ] [ text "+ Oxycodone 5mg (PRN)" ]
                , button [ class "prn", onClick (logDrug model "oxy-ir" 10.0 True) ] [ text "+ Oxycodone 10mg (PRN)" ]
                , button [ class "reg", onClick (logDrug model "tap-ir" 50.0 False) ] [ text "+ Tapentadol 50mg (Reg)" ]
                ]
            ]

        -- Recent Event Log
        , div [ class "card" ]
            [ h3 [ style "font-size" "0.95rem", style "color" "var(--text-muted)", style "margin-bottom" "8px" ] [ text "Recent Intake Log" ]
            , if List.isEmpty model.boluses then
                p [ style "font-size" "0.85rem", style "color" "var(--text-muted)" ] [ text "No doses logged yet." ]

              else
                div []
                    (List.take 8 model.boluses
                        |> List.map
                            (\b ->
                                div [ class "history-item" ]
                                    [ div []
                                        [ div [ style "font-weight" "600" ] [ text (b.drugName ++ " " ++ fromFloat b.doseMg ++ "mg") ]
                                        , div [ style "font-size" "0.75rem", style "color" "var(--text-muted)" ]
                                            [ text (roundOneDec b.omedd ++ " mg oMEDD") ]
                                        ]
                                    , span [ class (if b.isPrn then "badge-prn" else "badge-reg") ]
                                        [ text (if b.isPrn then "PRN" else "Regular") ]
                                    ]
                            )
                    )
            ]
        ]

logDrug : Model -> String -> Float -> Bool -> Msg
logDrug model drugId dose isPrn =
    case List.filter (\d -> d.id == drugId) model.availableDrugs |> List.head of
        Just drug ->
            LogPresetBolus drug dose isPrn

        Nothing ->
            Tick model.currentTime

roundOneDec : Float -> String
roundOneDec val =
    fromFloat (toFloat (round (val * 10.0)) / 10.0)

subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Time.every 1000 Tick
        , Ports.onInitialDataLoaded InitialDataReceived
        ]

main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }