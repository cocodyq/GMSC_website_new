module Filter exposing (BrowsePost(..),ShowPost(..),APIResult(..),MultiResult(..), Model, Msg(..), initialState, update, viewModel)

import Html exposing (..)
import Html.Events exposing (..)
import Bootstrap.CDN as CDN
import Bootstrap.Grid as Grid

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

type alias SequenceResultFull =
    { aa: Maybe String
    , habitat: Maybe String
    , nuc: Maybe String
    , seqid: String
    , tax: Maybe String  }

type alias MultiResultItem =
    { aa: String
    , habitat: String
    , nuc: String
    , seqid: String
    , tax: String  }

type alias Model =
    { browsepost : BrowsePost
    , showpost : ShowPost
    , times : Int
    , myDrop1State : Dropdown.State
    }

type BrowsePost
    = BLoading
    | BLoadError String
    | Results APIResult

type ShowPost
    = SLoading
    | SLoadError String
    | MultiResults MultiResult

decodeSequenceResult : D.Decoder SequenceResultFull
decodeSequenceResult = 
    D.map5 SequenceResultFull
           (D.maybe (D.field "aminoacid" D.string))
           (D.maybe (D.field "habitat" D.string))
           (D.maybe (D.field "nucleotide" D.string))
           ((D.field "seq_id" D.string))
           (D.maybe (D.field "taxonomy" D.string))

decodeMultItemResult : D.Decoder MultiResultItem
decodeMultItemResult = 
    D.map5 MultiResultItem
           (D.field "aminoacid" D.string)
           (D.field "habitat" D.string)
           (D.field "nucleotide" D.string)
           (D.field "seq_id" D.string)
           (D.field "taxonomy" D.string)

type APIResult =
        APIResultOK { results : List SequenceResultFull
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
    | Shownext (List SequenceResultFull)
    | Showlast (List SequenceResultFull)
    | Showfinal (List SequenceResultFull) Int
    | Showbegin (List SequenceResultFull) Int
    | Showselect (List SequenceResultFull) Int
    | MyDrop1Msg Dropdown.State

decodeAPIResult : D.Decoder APIResult
decodeAPIResult =
    let
        bAPIResultOK r s = APIResultOK { results = r, status = s }
    in D.map2 bAPIResultOK
        (D.field "results" (D.list decodeSequenceResult))
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

initialState : String -> String -> String -> String -> String -> String -> String -> String -> String -> (Model, Cmd Msg)
initialState habitat taxonomy antifam terminal rnacode metat riboseq metap hq=
    ( { browsepost = BLoading
      , showpost = SLoading
      , times = 1
      , myDrop1State = Dropdown.initialState
      }
    , Http.post
    { url = "https://gmsc-api.big-data-biology.org/v1/seq-filter/"
    , body = Http.multipartBody
                [ Http.stringPart "habitat" habitat
                , Http.stringPart "taxonomy" taxonomy
                , Http.stringPart "quality_antifam" antifam
                , Http.stringPart "quality_terminal" terminal
                , Http.stringPart "quality_rnacode" rnacode
                , Http.stringPart "quality_metat" metat
                , Http.stringPart "quality_riboseq" riboseq
                , Http.stringPart "quality_metap" metap
                , Http.stringPart "hq_only" hq
                ]
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
                        let ids = ((List.take 100 ok.results) |> List.map(\seq -> seq.seqid))
                        in  ( {model | browsepost = Results v, showpost = SLoading}
                            , Http.post
                              { url = "https://gmsc-api.big-data-biology.org/v1/seq-info-multi/"
                              , body = Http.jsonBody (multi ids)
                              , expect = Http.expectJson MultiData decodeMultiResult
                              }
                            )
                   _ -> ( {model | browsepost = Results v}, Cmd.none)
            Err err -> case err of
                Http.BadUrl s -> ({model | browsepost = BLoadError ("Bad URL: "++ s)}, Cmd.none)
                Http.Timeout  -> ({model | browsepost = BLoadError ("Timeout")}, Cmd.none)
                Http.NetworkError -> ({model | browsepost = BLoadError ("Network error!")}, Cmd.none)
                Http.BadStatus s -> ({model | browsepost = BLoadError (("Bad status: " ++ String.fromInt s))}, Cmd.none)
                Http.BadBody s -> ({model | browsepost = BLoadError (("Bad body: " ++ s))}, Cmd.none)

        DownloadResults -> case model.showpost of
            MultiResults r -> case r of
                MultiResultOK v -> 
                    let allresults = String.join "\n" 
                            (v 
                                |> (List.map 
                                        (\seq -> 
                                            String.join "\t" [seq.seqid,seq.aa,seq.nuc,seq.habitat,seq.tax]
                                        )
                                    )
                            )
                    in ( model, Download.string "result.tsv" "text/plain" allresults)
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
        
        Showlast l -> let ids = ((List.take 100 l)|> List.map(\seq -> seq.seqid))
                      in  ( {model | showpost = SLoading, times = (model.times-1)}
                          , Http.post
                          { url = "https://gmsc-api.big-data-biology.org/v1/seq-info-multi/"
                          , body = Http.jsonBody (multi ids)
                          , expect = Http.expectJson MultiData decodeMultiResult
                          }
                          )
        
        Shownext o -> let ids = ((List.take 100 o)|> List.map(\seq -> seq.seqid))
                      in  ( {model | showpost = SLoading, times = (model.times+1)}
                          , Http.post
                          { url = "https://gmsc-api.big-data-biology.org/v1/seq-info-multi/"
                          , body = Http.jsonBody (multi ids)
                          , expect = Http.expectJson MultiData decodeMultiResult
                          }
                          )

        Showfinal o all -> let ids = ((List.take 100 o)|> List.map(\seq -> seq.seqid))
                      in  ( {model | showpost = SLoading, times = all}
                          , Http.post
                          { url = "https://gmsc-api.big-data-biology.org/v1/seq-info-multi/"
                          , body = Http.jsonBody (multi ids)
                          , expect = Http.expectJson MultiData decodeMultiResult
                          }
                          )

        Showbegin o all -> let ids = ((List.take 100 o)|> List.map(\seq -> seq.seqid))
                      in  ( {model | showpost = SLoading, times = all}
                          , Http.post
                          { url = "https://gmsc-api.big-data-biology.org/v1/seq-info-multi/"
                          , body = Http.jsonBody (multi ids)
                          , expect = Http.expectJson MultiData decodeMultiResult
                          }
                          )        
        Showselect o all -> let ids = ((List.take 100 o)|> List.map(\seq -> seq.seqid))
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
                    [ text "Loading..."
                    ]
        SLoadError e ->
                div []
                    [ text "Error "
                    , text e
                    ]
        MultiResults r -> 
            case model.browsepost of 
                Results b ->
                    viewResults r b model.times model
                _ -> div []
                    [ text "Loading..."
                    ]


viewResults r b times model = case r of
    MultiResultOK ok ->
        case b of 
            APIResultOK bok ->
                div []
                    [ if List.length bok.results /= 0 then
                        div [id "position"] [Button.button [ Button.info, Button.onClick DownloadResults] [ Html.text "Download results" ] ]
                      else div [] [text ""]
                    , if List.isEmpty ok then
                            text "No small proteins in the selected habitats and/or taxonomy. Please try another selection."
                      else div []
                        [ div [id "member"]
                            [ Table.table
                                { options = [ Table.striped, Table.hover ]
                                , thead =  Table.simpleThead
                                    [ Table.th [] [ Html.text "90AA accession" ]
                                    , Table.th [] [ Html.text "Consensus protein sequence" ]
                                    , Table.th [] [ Html.text "Consensus nucleotide sequence" ]
                                    , Table.th [] [ Html.text "Habitat" ]
                                    , Table.th [] [ Html.text "Taxonomy" ]
                                    ]
                                , tbody = Table.tbody []
                                        (List.map (\e ->
                                                        Table.tr []
                                                        [  Table.td [] [ p [id "identifier"] [Html.a [href ("/cluster/" ++ e.seqid)] [Html.text e.seqid] ] ]
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
                            [ if List.length bok.results > 100 then
                                    if List.length bok.results > (100*times) then
                                        div [] [ p [] [ text ("Displaying " ++ String.fromInt (100*times-99) ++ " to " ++ String.fromInt (100*times) ++ " of " ++ String.fromInt (List.length bok.results) ++ " items.") ] ]
                                    else
                                        div [] [ p [] [ text ("Displaying " ++ String.fromInt (100*times-99) ++ " to " ++ String.fromInt (List.length bok.results) ++ " of " ++ String.fromInt (List.length bok.results) ++ " items.") ] ]
                                else if List.length bok.results /= 0 then
                                            div [] [ p [] [ text ("Displaying " ++ String.fromInt 1 ++ " to " ++ String.fromInt (List.length bok.results) ++ " of " ++ String.fromInt (List.length bok.results) ++ " items.") ] ]
                                    else 
                                            div [] [ text "" ]
                                , if List.length bok.results > 100 then
                                        Button.button [ Button.small, Button.outlineInfo, Button.attrs [ Spacing.ml1 ] , Button.onClick (Showbegin bok.results 1), Button.attrs [ class "float-left"]] [ Html.text "<<" ]
                                    else Button.button [ Button.small, Button.outlineInfo, Button.attrs [ Spacing.ml1 ], Button.attrs [ class "float-left"]] [ Html.text "<<" ]
                                , if times > 1 then
                                    let other = (List.drop (100*(times-2)) bok.results)
                                    in Button.button [ Button.small, Button.outlineInfo, Button.attrs [ Spacing.ml1 ] , Button.onClick (Showlast other), Button.attrs [ class "float-left"]] [ Html.text "<" ]
                                else Button.button [ Button.small, Button.outlineInfo, Button.attrs [ Spacing.ml1 ], Button.attrs [ class "float-left"]] [ Html.text "<" ]
                                {-, if List.length bok.results > 100 then
                                    if modBy 100 (List.length bok.results) /= 0 then
                                        div [] (List.map (\n -> Button.button [ Button.small, Button.outlineInfo, Button.onClick (Showselect (List.drop (100*(n-1)) bok.results) n) ] [text (String.fromInt n)] )(List.range 1 ((List.length bok.results//100)+1)))
                                    else 
                                        div [] (List.map (\n -> Button.button [ Button.small, Button.outlineInfo, Button.onClick (Showselect (List.drop (100*(n-1)) bok.results) n) ] [text (String.fromInt n)] )(List.range 1 ((List.length bok.results//100))))
                                  else Button.button [ Button.small, Button.outlineInfo ] [text "1"]-}
                                , div [HtmlAttr.style "float" "left"]
                                    [ Dropdown.dropdown
                                        model.myDrop1State
                                        { options = [ ]
                                        , toggleMsg = MyDrop1Msg
                                        , toggleButton =
                                            Dropdown.toggle [ Button.small, Button.outlineInfo ,Button.attrs [ class "float-left"]] [ text "Page" ]
                                        , items =
                                            if List.length bok.results > 100 then
                                                if modBy 100 (List.length bok.results) /= 0 then
                                                    (List.map (\n -> Dropdown.buttonItem [ onClick (Showselect (List.drop (100*(n-1)) bok.results) n) ] [text (String.fromInt n)] )(List.range 1 ((List.length bok.results//100)+1)))
                                                else
                                                    (List.map (\n -> Dropdown.buttonItem [ onClick (Showselect (List.drop (100*(n-1)) bok.results) n) ] [text (String.fromInt n)] )(List.range 1 ((List.length bok.results//100))))
                                            else
                                                [ Dropdown.buttonItem [] [ text "1" ] ]
                                        }
                                ]
                                , if List.length bok.results >(100*times) then
                                    let other = (List.drop (100*times) bok.results)
                                    in Button.button [ Button.small, Button.outlineInfo, Button.attrs [ Spacing.ml1 ] , Button.onClick (Shownext other)] [ Html.text ">" ]
                                else Button.button [ Button.small, Button.outlineInfo, Button.attrs [ Spacing.ml1 ]] [ Html.text ">" ]
                                , if List.length bok.results > 100 then
                                        let 
                                            (other,all) = if modBy 100 (List.length bok.results) /= 0 then
                                                            ((List.drop (100* (List.length bok.results//100)) bok.results),((List.length bok.results//100) + 1))
                                                        else
                                                            ((List.drop (100* ((List.length bok.results//100)-1)) bok.results), (List.length bok.results//100))
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