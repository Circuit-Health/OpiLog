module Calculations exposing (computeSummary, bolusToOmedd, patchToOmeddPerHour)

import Types exposing (BolusEntry, MetricsSummary, OpioidDrug, PatchEntry, WindowMetrics)

bolusToOmedd : Float -> Float -> Float
bolusToOmedd doseMg factor =
    doseMg * factor

-- Transdermal: Norspan (Buprenorphine mcg/hr) * 2 = mg/day oMEDD. Durogesic (Fentanyl mcg/hr) * 3 = mg/day oMEDD.
-- oMEDD per hour = (ratedMcg * factor) / 24.0
patchToOmeddPerHour : Float -> Float -> Float
patchToOmeddPerHour ratedMcg factor =
    (ratedMcg * factor) / 24.0

computeSummary : Int -> List BolusEntry -> List PatchEntry -> MetricsSummary
computeSummary nowMs boluses patches =
    { window1Day = computeWindow nowMs 1 boluses patches
    , window3Day = computeWindow nowMs 3 boluses patches
    , window7Day = computeWindow nowMs 7 boluses patches
    }

computeWindow : Int -> Int -> List BolusEntry -> List PatchEntry -> WindowMetrics
computeWindow nowMs days boluses patches =
    let
        windowDurationMs =
            days * 24 * 60 * 60 * 1000

        windowStartMs =
            nowMs - windowDurationMs

        windowEndMs =
            nowMs

        -- 1. Aggregate Bolus Entries
        inWindowBoluses =
            List.filter (\b -> b.timestampMs >= windowStartMs && b.timestampMs <= windowEndMs) boluses

        bolusPrnTotal =
            inWindowBoluses
                |> List.filter .isPrn
                |> List.map .omedd
                |> List.sum

        bolusSchedTotal =
            inWindowBoluses
                |> List.filter (\b -> not b.isPrn)
                |> List.map .omedd
                |> List.sum

        -- 2. Aggregate Transdermal Patch Overlaps
        computePatchExposure : PatchEntry -> Float
        computePatchExposure p =
            let
                patchEnd =
                    Maybe.withDefault windowEndMs p.removedAtMs

                effectiveStart =
                    max windowStartMs p.appliedAtMs

                effectiveEnd =
                    min windowEndMs patchEnd
            in
            if effectiveEnd > effectiveStart then
                let
                    activeHours =
                        toFloat (effectiveEnd - effectiveStart) / (1000.0 * 3600.0)
                in
                activeHours * p.omeddPerHour

            else
                0.0

        patchTotal =
            patches
                |> List.map computePatchExposure
                |> List.sum

        totalOmedd =
            bolusPrnTotal + bolusSchedTotal + patchTotal

        dailyAvg =
            totalOmedd / toFloat days
    in
    { totalOmedd = totalOmedd
    , dailyAverage = dailyAvg
    , prnOmedd = bolusPrnTotal
    , scheduledOmedd = bolusSchedTotal + patchTotal
    }