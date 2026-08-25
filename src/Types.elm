module Types exposing (..)

import Time

type OpioidRoute
    = Oral
    | Sublingual
    | TransdermalPatch

type alias OpioidDrug =
    { id : String
    , name : String
    , route : OpioidRoute
    , conversionFactor : Float -- Multiplier to oral Morphine Equivalent (mg)
    , defaultWearHours : Int   -- e.g. 72 for Fentanyl, 168 for Buprenorphine, 0 for bolus
    }

type alias BolusEntry =
    { id : String
    , drugId : String
    , drugName : String
    , timestampMs : Int
    , doseMg : Float
    , isPrn : Bool
    , omedd : Float
    }

type alias PatchEntry =
    { id : String
    , drugId : String
    , drugName : String
    , appliedAtMs : Int
    , removedAtMs : Maybe Int
    , ratedDeliveryRateMcg : Float
    , omeddPerHour : Float
    }

type alias WindowMetrics =
    { totalOmedd : Float
    , dailyAverage : Float
    , prnOmedd : Float
    , scheduledOmedd : Float
    }

type alias MetricsSummary =
    { window1Day : WindowMetrics
    , window3Day : WindowMetrics
    , window7Day : WindowMetrics
    }