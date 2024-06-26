module Members exposing (MemberPost(..), ShowPost (..), APIResult(..), MultiResult(..), Model, Msg(..), initialState, update, viewModel)

import Html exposing (..)
import Html.Events exposing (..)
import Bootstrap.Grid as Grid

import Chart as C
import Chart.Attributes as CA

import Html.Attributes as HtmlAttr
import Html.Attributes exposing (..)
import Browser
import Dict
import Markdown
import View exposing (View)

import Bootstrap.Table as Table
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.Button as Button
import Bootstrap.Dropdown as Dropdown
import Bootstrap.Utilities.Spacing as Spacing
import Json.Decode as D
import Json.Encode as Encode
import File.Download as Download
import Http

type SequenceResult =
    SequenceResultFull
        { seqid: String
        , aa: String
        , habitat: String
        , nuc: String
        , tax: String  }
    | SequenceResultShallow { seqid: String }

type alias MultiResultItem =
    { aa: String
    , habitat: String
    , nuc: String
    , seqid: String
    , tax: String  }

type alias Model =
    { memberpost : MemberPost
    , showpost : ShowPost
    , times : Int
    , myDrop1State : Dropdown.State
    }

type MemberPost
    = MLoading
    | MLoadError String
    | Results APIResult

type ShowPost
    = SLoading
    | SLoadError String
    | MultiResults MultiResult

decodeSequenceResult : D.Decoder SequenceResult
decodeSequenceResult =
    D.oneOf
        [D.map5 (\s a h n t -> SequenceResultFull { seqid = s, aa = a, habitat = h, nuc = n, tax = t })
           (D.field "seq_id" D.string)
           (D.field "aminoacid" D.string)
           (D.field "habitat" D.string)
           (D.field "nucleotide" D.string)
           (D.field "taxonomy" D.string)
        , D.map (\s -> SequenceResultShallow { seqid = s })
            (D.field "seq_id" D.string)
        ]

decodeMultItemResult : D.Decoder MultiResultItem
decodeMultItemResult = 
    D.map5 MultiResultItem
           (D.field "aminoacid" D.string)
           (D.field "habitat" D.string)
           (D.field "nucleotide" D.string)
           (D.field "seq_id" D.string)
           (D.field "taxonomy" D.string)

type APIResult =
        APIResultOK { cluster : List SequenceResult
                    , status : String
                    }
        | APIError String

type MultiResult =
        MultiResultOK (List MultiResultItem)
        | MultiError String

type Msg
    = ResultsData (Result Http.Error APIResult)
    | DownloadResults
    | MultiData (Result Http.Error MultiResult)
    | Shownext (List SequenceResult)
    | Showlast (List SequenceResult)
    | Showfinal (List SequenceResult) Int
    | Showbegin (List SequenceResult) Int
    | Showselect (List SequenceResult) Int
    | MyDrop1Msg Dropdown.State

decodeAPIResult : D.Decoder APIResult
decodeAPIResult =
    let
        bAPIResultOK r s = APIResultOK { cluster = r, status = s }
    in D.map2 bAPIResultOK
        (D.field "cluster" (D.list decodeSequenceResult))
        (D.field "status" D.string)

decodeMultiResult : D.Decoder MultiResult
decodeMultiResult =
    let
        bMultiResultOK r = MultiResultOK r
    in D.map bMultiResultOK
        (D.list decodeMultItemResult)

multi : List String -> Encode.Value
multi ids =
    Encode.object
        [  ("seq_ids", Encode.list Encode.string ids)
        ]

initialState : String -> (Model, Cmd Msg)
initialState seq_id = 
    ( { memberpost = MLoading
      , showpost = SLoading
      , times = 1
      , myDrop1State = Dropdown.initialState
      }
    , Http.get
    { url = ("https://gmsc-api.big-data-biology.org/v1/cluster-info/" ++ seq_id)
    , expect = Http.expectJson ResultsData decodeAPIResult
    }
    )

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ResultsData r -> case r of
            Ok v -> 
                case v of 
                   APIResultOK ok ->
                        let ids = ((List.take 100 ok.cluster) |> List.map(\seq -> 
                                                                            case seq of 
                                                                                SequenceResultFull full -> full.seqid
                                                                                SequenceResultShallow shallow -> shallow.seqid))
                        in  ( {model | memberpost = Results v, showpost = SLoading}
                            , Http.post
                              { url = "https://gmsc-api.big-data-biology.org/v1/seq-info-multi/"
                              , body = Http.jsonBody (multi ids)
                              , expect = Http.expectJson MultiData decodeMultiResult
                              }
                            )
                   _ -> ( {model | memberpost = Results v}, Cmd.none)
            Err err -> case err of
                Http.BadUrl s -> ({model | memberpost = MLoadError ("Bad URL: "++ s)}, Cmd.none)
                Http.Timeout  -> ({model | memberpost = MLoadError ("Timeout")}, Cmd.none)
                Http.NetworkError -> ({model | memberpost = MLoadError ("Network error!")}, Cmd.none)
                Http.BadStatus s -> ({model | memberpost = MLoadError (("Bad status: " ++ String.fromInt s))}, Cmd.none)
                Http.BadBody s -> ({model | memberpost = MLoadError (("Bad body: " ++ s))}, Cmd.none)
                
        DownloadResults -> case model.showpost of
            MultiResults r -> case r of
                MultiResultOK v -> 
                    let allresults = v |> List.map (\seq -> String.join "\t" [seq.seqid, seq.aa, seq.nuc, seq.habitat, seq.tax])
                                            |> String.join "\n"
                    in ( model, Download.string "cluster.members.tsv" "text/plain" allresults)
                _ -> ( model, Cmd.none )
            _ -> ( model, Cmd.none )

        MultiData r -> case r of
            Ok m -> ( {model | showpost = MultiResults m}, Cmd.none )
            Err err -> case err of
                Http.BadUrl s -> ({model | showpost = SLoadError ("Bad URL: "++ s)}, Cmd.none)
                Http.Timeout  -> ({model | showpost = SLoadError ("Timeout")}, Cmd.none)
                Http.NetworkError -> ({model | showpost = SLoadError ("Network error!")}, Cmd.none)
                Http.BadStatus s -> ({model | showpost = SLoadError (("Bad status: " ++ String.fromInt s))}, Cmd.none)
                Http.BadBody s -> ({model | showpost = SLoadError (("Bad body: " ++ s))}, Cmd.none)
        
        Showlast l -> let ids = ((List.take 100 l)|> List.map(\seq -> 
                                                                case seq of 
                                                                    SequenceResultFull full -> full.seqid
                                                                    SequenceResultShallow shallow -> shallow.seqid))
                      in  ( {model | showpost = SLoading, times = (model.times-1)}
                          , Http.post
                          { url = "https://gmsc-api.big-data-biology.org/v1/seq-info-multi/"
                          , body = Http.jsonBody (multi ids)
                          , expect = Http.expectJson MultiData decodeMultiResult
                          }
                          )
        
        Shownext o -> let ids = ((List.take 100 o)|> List.map(\seq -> 
                                                                case seq of 
                                                                    SequenceResultFull full -> full.seqid
                                                                    SequenceResultShallow shallow -> shallow.seqid))
                      in  ( {model | showpost = SLoading, times = (model.times+1)}
                          , Http.post
                          { url = "https://gmsc-api.big-data-biology.org/v1/seq-info-multi/"
                          , body = Http.jsonBody (multi ids)
                          , expect = Http.expectJson MultiData decodeMultiResult
                          }
                          )

        Showfinal o all -> let ids = ((List.take 100 o)|> List.map(\seq -> 
                                                                case seq of 
                                                                    SequenceResultFull full -> full.seqid
                                                                    SequenceResultShallow shallow -> shallow.seqid))
                      in  ( {model | showpost = SLoading, times = all}
                          , Http.post
                          { url = "https://gmsc-api.big-data-biology.org/v1/seq-info-multi/"
                          , body = Http.jsonBody (multi ids)
                          , expect = Http.expectJson MultiData decodeMultiResult
                          }
                          )

        Showbegin o all -> let ids = ((List.take 100 o)|> List.map(\seq -> 
                                                                case seq of 
                                                                    SequenceResultFull full -> full.seqid
                                                                    SequenceResultShallow shallow -> shallow.seqid))
                      in  ( {model | showpost = SLoading, times = all}
                          , Http.post
                          { url = "https://gmsc-api.big-data-biology.org/v1/seq-info-multi/"
                          , body = Http.jsonBody (multi ids)
                          , expect = Http.expectJson MultiData decodeMultiResult
                          }
                          )

        Showselect o all -> let ids = ((List.take 100 o)|> List.map(\seq -> 
                                                                case seq of 
                                                                    SequenceResultFull full -> full.seqid
                                                                    SequenceResultShallow shallow -> shallow.seqid))
                      in  ( {model | showpost = SLoading, times = all}
                          , Http.post
                          { url = "https://gmsc-api.big-data-biology.org/v1/seq-info-multi/"
                          , body = Http.jsonBody (multi ids)
                          , expect = Http.expectJson MultiData decodeMultiResult
                          }
                          )
        MyDrop1Msg state ->
            ( { model | myDrop1State = state }
            , Cmd.none
            )

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Dropdown.subscriptions model.myDrop1State MyDrop1Msg ]

viewModel : Model-> Html Msg
viewModel model =
    case model.showpost of
        SLoading ->
                div []
                    [ p [] [text "Loading..."]
                    ]
        SLoadError e ->
                div []
                    [ text "Error "
                    , text e
                    ]
        MultiResults r -> 
            case model.memberpost of 
                Results m ->
                    viewResults r m model.times model
                _ -> div []
                    [ p [] [text "Loading..."]
                    ]

viewResults r m times model = case r of
    MultiResultOK ok ->
        case m of 
            APIResultOK mok ->
                Html.div []
                    [ viewSummary mok
                    , Html.div []
                        [ Html.p [HtmlAttr.style "float" "left"] [ Html.text ("Number of smORFs in cluster: " ++ String.fromInt (List.length mok.cluster) )]
                        , Html.div []
                            ( if anyShallow mok.cluster then 
                                [ Html.p [HtmlAttr.style "float" "left"] [ Html.strong [] [Html.text "Note: The cluster is too large. Not displaying the distribution of all sequences"] ] ]
                              else []
                            )
                        , div [id "position"] [Button.button [ Button.info, Button.onClick DownloadResults] [ Html.text "Download members" ]]
                        , div [id "member"] 
                          [ Table.table
                            { options = [ Table.striped, Table.hover ]
                            , thead =  Table.simpleThead
                                [ Table.th [] [ Html.text "100AA accession" ]
                                , Table.th [] [ Html.text "Protein sequence" ]
                                , Table.th [] [ Html.text "Nucleotide sequence" ]
                                , Table.th [] [ Html.text "Habitat" ]
                                , Table.th [] [ Html.text "Taxonomy" ]
                                ]
                            , tbody = Table.tbody []
                                    ( List.map (\e ->
                                                    Table.tr []
                                                    [  Table.td [] [ p [id "identifier"] [Html.a [href ("/sequence/" ++ e.seqid)] [Html.text e.seqid] ] ]
                                                    ,  Table.td [] [ p [id "detail"] [text e.aa ] ]
                                                    ,  Table.td [] [ p [id "detail"] [text e.nuc ] ]
                                                    ,  Table.td [] [ p [id "detail"] [text e.habitat ] ]
                                                    ,  Table.td [] [ p [id "detail"] [text e.tax ] ]
                                                    ]
                                               ) ok
                                    )
                            }
                          ]
                        , div [class "browse"] 
                          [ if List.length mok.cluster > 100 then
                                if List.length mok.cluster > (100*times) then
                                    div [] [ p [] [ text ("Displaying " ++ String.fromInt (100*times-99) ++ " to " ++ String.fromInt (100*times) ++ " of " ++ String.fromInt (List.length mok.cluster) ++ " items.") ] ]
                                else
                                    div [] [ p [] [ text ("Displaying " ++ String.fromInt (100*times-99) ++ " to " ++ String.fromInt (List.length mok.cluster) ++ " of " ++ String.fromInt (List.length mok.cluster) ++ " items.") ] ]
                            else 
                                div [] [ p [] [ text ("Displaying " ++ String.fromInt 1 ++ " to " ++ String.fromInt (List.length mok.cluster) ++ " of " ++ String.fromInt (List.length mok.cluster) ++ " items.") ] ]
                            , if List.length mok.cluster > 100 then
                                Button.button [ Button.small, Button.outlineInfo, Button.attrs [ Spacing.ml1 ] , Button.onClick (Showbegin mok.cluster 1), Button.attrs [ class "float-left"]] [ Html.text "<<" ]
                              else Button.button [ Button.small, Button.outlineInfo, Button.attrs [ Spacing.ml1 ], Button.attrs [ class "float-left"]] [ Html.text "<<" ]
                            , if times > 1 then
                                let other = (List.drop (100*(times-2)) mok.cluster)
                                in Button.button [ Button.small, Button.outlineInfo, Button.attrs [ Spacing.ml1 ] , Button.onClick (Showlast other), Button.attrs [ class "float-left"]] [ Html.text "<" ]
                              else Button.button [ Button.small, Button.outlineInfo, Button.attrs [ Spacing.ml1 ] , Button.attrs [ class "float-left"]] [ Html.text "<" ]
                            {-, if List.length mok.cluster > 100 then
                                if modBy 100 (List.length mok.cluster) /= 0 then
                                    div [] (List.map (\n -> Button.button [ Button.small, Button.outlineInfo, Button.onClick (Showselect (List.drop (100*(n-1)) mok.cluster) n) ,Button.attrs [ class "float-left"]] [text (String.fromInt n)] )(List.range 1 ((List.length mok.cluster//100)+1)))
                                else 
                                    div [] (List.map (\n -> Button.button [ Button.small, Button.outlineInfo, Button.onClick (Showselect (List.drop (100*(n-1)) mok.cluster) n) ] [text (String.fromInt n)] )(List.range 1 ((List.length mok.cluster//100))))
                              else Button.button [ Button.small, Button.outlineInfo ] [text "1"]-}
                            , div [HtmlAttr.style "float" "left"]
                                [ Dropdown.dropdown
                                    model.myDrop1State
                                    { options = [ ]
                                    , toggleMsg = MyDrop1Msg
                                    , toggleButton =
                                        Dropdown.toggle [ Button.small, Button.outlineInfo ,Button.attrs [ class "float-left"]] [ text "Page" ]
                                    , items =
                                        if List.length mok.cluster > 100 then
                                            if modBy 100 (List.length mok.cluster) /= 0 then
                                                (List.map (\n -> Dropdown.buttonItem [ onClick (Showselect (List.drop (100*(n-1)) mok.cluster) n) ] [text (String.fromInt n)] )(List.range 1 ((List.length mok.cluster//100)+1)))
                                            else
                                                (List.map (\n -> Dropdown.buttonItem [ onClick (Showselect (List.drop (100*(n-1)) mok.cluster) n) ] [text (String.fromInt n)] )(List.range 1 ((List.length mok.cluster//100))))
                                        else
                                            [ Dropdown.buttonItem [] [ text "1" ] ]
                                    }
                                ]
                            , if List.length mok.cluster >(100*times) then
                                let other = (List.drop (100*times) mok.cluster)
                                in Button.button [ Button.small, Button.outlineInfo, Button.attrs [ Spacing.ml1 ] , Button.onClick (Shownext other)] [ Html.text ">" ]
                              else Button.button [ Button.small, Button.outlineInfo, Button.attrs [ Spacing.ml1 ]] [ Html.text ">" ]
                            , if List.length mok.cluster > 100 then
                                let 
                                    (other,all) = if modBy 100 (List.length mok.cluster) /= 0 then
                                                    ((List.drop (100* (List.length mok.cluster//100)) mok.cluster),((List.length mok.cluster//100) + 1))
                                                  else
                                                    ((List.drop (100* ((List.length mok.cluster//100)-1)) mok.cluster), (List.length mok.cluster//100))
                                in Button.button [ Button.small, Button.outlineInfo, Button.attrs [ Spacing.ml1 ] , Button.onClick (Showfinal other all)] [ Html.text ">>" ]
                              else Button.button [ Button.small, Button.outlineInfo, Button.attrs [ Spacing.ml1 ]] [ Html.text ">>" ]
                          ]
                        ]
                    ]
                    
            APIError berr -> div []
                    [ Html.p [] [ Html.text "Call to the GMSC server failed" ]
                    , Html.blockquote []
                        [ Html.p [] [ Html.text berr ] ]
                    ]
    MultiError err ->
        div []
            [ Html.p [] [ Html.text "Call to the GMSC server failed" ]
            , Html.blockquote []
                [ Html.p [] [ Html.text err ] ]
            ]


anyShallow : List SequenceResult -> Bool
anyShallow =
    List.any (\e -> case e of
        SequenceResultShallow _ -> True
        SequenceResultFull _ -> False
        )

viewSummary ok =
    let
        datahabitat = summaryForhabitat ok.cluster
        datatax = summaryFortax ok.cluster
    in Html.div []
        [ Html.div 
          [ HtmlAttr.style "width" "460px"
          , HtmlAttr.style "margin-left" "4em"
          , HtmlAttr.style "float" "left"
          ]
            [ Html.h5 [] [Html.text "Habitat distribution"]
            , C.chart
              [ CA.height 190
              , CA.width 460
              , CA.margin { top = 10, bottom = 40, left = 20, right = 20 }
              , CA.padding { top = 10, bottom = 10, left = 10, right = 10 }
              ]
              [ C.grid []
              , C.binLabels .habitat [ CA.moveDown 20, CA.fontSize 12 ]
              , C.yLabels [ CA.withGrid, CA.fontSize 12 ]
              , C.bars []
                [ C.bar .count [CA.color CA.green]
                ]
                datahabitat
              ]
            ]
        , Html.div
          [ HtmlAttr.style "width" "460px"
          , HtmlAttr.style "margin-left" "4em"
          , HtmlAttr.style "float" "left"
          ]
            [ Html.h5 [] [Html.text "Taxonomy distribution"]
            , C.chart
              [ CA.height 190
              , CA.width 460
              , CA.margin { top = 10, bottom = 40, left = 20, right = 20 }
              , CA.padding { top = 10, bottom = 10, left = 10, right = 10 }
              ]
              [ C.binLabels .tax [ CA.moveDown 50, CA.fontSize 12, CA.rotate 20 ]
              , C.yLabels [ CA.withGrid, CA.fontSize 12 ]
              , C.bars []
                [ C.bar .count [CA.color CA.blue]
                ]
                datatax
              ]
            ]
        ]


summaryForhabitat : List SequenceResult -> List ({ habitat : String, count : Float })
summaryForhabitat seqs =
    let
        add1 : Maybe Float -> Maybe Float
        add1 c = case c of
            Nothing -> Just 1.0
            Just x -> Just (x + 1.0)
    in
        List.foldl (\e acc -> case e of
                                SequenceResultShallow _ -> acc
                                SequenceResultFull f -> Dict.update f.habitat add1 acc) Dict.empty seqs
        |> Dict.toList
        |> List.map (\(habitat, count) -> { habitat = habitat, count = count })

summaryFortax : List SequenceResult -> List ({ tax : String, count : Float })
summaryFortax seqs =
    let
        add1 : Maybe Float -> Maybe Float
        add1 c = case c of
            Nothing -> Just 1.0
            Just x -> Just (x + 1.0)
    in
        List.foldl (\e acc -> case e of
                                SequenceResultShallow _ -> acc
                                SequenceResultFull f -> 
                                    let taxlist = List.reverse (String.split ";" f.tax)
                                        species = if List.length taxlist == 7 then
                                                    String.join "" (List.take 1 taxlist)
                                                  else
                                                    "Unknown"                                                    
                                    in Dict.update species add1 acc) Dict.empty seqs
        |> Dict.toList
        |> List.map (\(tax, count) -> { tax = tax, count = count })