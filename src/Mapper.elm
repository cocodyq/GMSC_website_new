module Mapper exposing (Model, Msg(..), initialState, lookupState, update, viewModel)

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes as HtmlAttr
import Html.Attributes exposing (..)
import Browser.Navigation as Nav
import Browser
import Dict
import Markdown
import Http

import Bootstrap.CDN as CDN
import Bootstrap.Grid as Grid
import Bootstrap.Table as Table
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.Button as Button
import Bootstrap.Dropdown as Dropdown
import Json.Decode as D
import Delay

import View exposing (View)
import Route exposing (Route)

type alias QueryResult =
  { seqid : String
  , aa : String
  , habitat: String
  , hits: List HitsResult
  , quality: String
  , tax: String
  }

type alias HitsResult = 
    { e: Float
    , id: String
    , identity: Float
    }

type alias SequenceResult =
    { aa: String
    , habitat: String
    , hits: List HitsResult
    , quality: String
    , tax: String
    }

type alias SearchResult =
    { results : Maybe (Dict.Dict String QueryResult)
    , search_id : String
    , status : String
   }
type SearchResultOrError =
    SearchResultOk SearchResult
    | SearchResultError String


decodeSearchResult : D.Decoder SearchResultOrError
decodeSearchResult =
    let
        bSearchResultOK r i s = SearchResultOk { results = r, search_id = i, status = s }
    in D.map3 bSearchResultOK
        (D.maybe (D.field "results" decodeQueryResult))
        (D.field "search_id" D.string)
        (D.field "status" D.string)

decodeQueryResult : D.Decoder (Dict.Dict String QueryResult)
decodeQueryResult = D.map (Dict.map seqToquery) (D.dict decodeSequenceResult)

seqToquery : String -> SequenceResult -> QueryResult
seqToquery seqid { aa, habitat, hits, quality, tax } =
  QueryResult seqid aa habitat hits quality tax

decodeSequenceResult : D.Decoder SequenceResult
decodeSequenceResult = 
    D.map5 SequenceResult
        (D.field "aminoacid" D.string)
        (D.field "habitat" D.string)
        (D.field "hits" (D.list decodeHitsResult))
        (D.field "quality" D.string)
        (D.field "taxonomy" D.string)

decodeHitsResult : D.Decoder HitsResult
decodeHitsResult =
    D.map3 HitsResult
        (D.field "evalue" D.float)
        (D.field "id" D.string)
        (D.field "identity" D.float)

type MapperPost = 
    Loading
    | LoadError String
    | SearchError String
    | Search SearchResult

type alias Model =
    { mapperpost :MapperPost
    , navKey : Nav.Key
    }

type Msg
    = SearchData (Result Http.Error SearchResultOrError)
    | Getresults String

initialState : String -> String -> Nav.Key -> (Model, Cmd Msg)
initialState seq is_contigs navkey =
    ( { mapperpost = Loading
    , navKey = navkey
    }
    , Http.post
    { url = "https://gmsc-api.big-data-biology.org/internal/seq-search/"
    , body = Http.multipartBody
                [ Http.stringPart "sequence_faa" seq
                , Http.stringPart "is_contigs" is_contigs
                ]
    , expect = Http.expectJson SearchData decodeSearchResult
    }
    )


lookupState : String -> Nav.Key -> (Model, Cmd Msg)
lookupState seq_id navkey =
    update (Getresults seq_id) {mapperpost = Loading, navKey = navkey}

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SearchData sd -> case sd of
            Ok (SearchResultOk v) ->
                ({model | mapperpost = Search v},
                    if v.status == "Done"
                    then Cmd.none
                    else Delay.after 5000 (Getresults v.search_id))
            Ok (SearchResultError e) -> ({model | mapperpost = SearchError e}, Cmd.none)
            Err err -> case err of
                Http.BadUrl s -> ({model | mapperpost = LoadError ("Bad URL: "++ s)}, Cmd.none)
                Http.Timeout  -> ({model | mapperpost = LoadError ("Timeout")}, Cmd.none)
                Http.NetworkError -> ({model | mapperpost = LoadError ("Network error!")}, Cmd.none)
                Http.BadStatus s -> ({model | mapperpost = LoadError (("Bad status: " ++ String.fromInt s))}, Cmd.none)
                Http.BadBody s -> ({model | mapperpost = LoadError (("Bad body: " ++ s))}, Cmd.none)

        Getresults id ->
                ( {model | mapperpost = Loading}
                , Http.get { url = ("https://gmsc-api.big-data-biology.org/internal/seq-search/" ++ id)
                                   , expect = Http.expectJson SearchData decodeSearchResult
                           }
                )

viewModel : Model-> Html Msg
viewModel model =
    case model.mapperpost of
        Loading ->
                div []
                    [ text "Loading..."
                    ]
        LoadError e ->
                div []
                    [ text "Error "
                    , text e
                    ]
        Search s -> viewSearch s
        SearchError err -> viewSearchError err

viewSearch : SearchResult -> Html Msg
viewSearch s  =
    if s.status == "Done" then
        case s.results of
          Just r ->
            div [id "member"]
                [ h2 [] [text ("Search id: " ++ s.search_id)]
                , h3 [] [text "Annotation of query sequences"]
                , Table.table
                    { options = [ Table.striped, Table.hover ]
                    , thead =  Table.simpleThead
                        [ Table.th [] [ Html.text "Query sequence" ]
                        , Table.th [] [ Html.text "Protein sequence" ]
                        , Table.th [] [ Html.text "Habitat" ]
                        , Table.th [] [ Html.text "Taxonomy" ]
                        , Table.th [] [ Html.text "Quality" ]
                        ]
                    , tbody = Table.tbody []
                      (Dict.toList r
                        |> List.map (\(k,v) ->
                            Table.tr []
                            [ Table.td [] [ p [id "detail"] [ text k ] ]
                            , Table.td [] [ p [id "detail"] [ text v.aa ] ]
                            , Table.td [] [ p [id "detail"] [ text v.habitat ] ]
                            , Table.td [] [ p [id "detail"] [ text v.tax ] ]
                            , if v.quality == "high quality"  then
                                 Table.td [] [ p [id "detail"] [ text "pass all quality tests & show experimental evidences" ] ]
                              else 
                                 Table.td [] [ p [id "detail"] [ text "not pass all quality tests or not show experimental evidences" ] ]
                            ]
                            )
                      )                  
                    }
                , h3 [] [text "Hits in GMSC"]
                , Table.table
                    { options = [ Table.striped, Table.hover ]
                    , thead =  Table.simpleThead
                        [ Table.th [] [ Html.text "Query sequence" ]
                        , Table.th [] [ Html.text "GMSC Hits" ]
                        ]
                    , tbody = Table.tbody []
                      (Dict.toList r
                        |> List.map (\(k,v) ->
                            Table.tr []
                            [ Table.td [] [ p [id "identifier"] [ text k ] ]
                            , Table.td [] [ p [id "mapper"] [ text 
                                                                (String.join " , " (v.hits 
                                                                    |> List.map (\hit -> hit.id ++ " ( e-value: " ++ (String.fromFloat hit.e) ++ ", identity:" ++ (String.fromFloat hit.identity) ++" )\n"))
                                                                )
                                                            ]
                                           ]
                            ]
                            )
                      )                  
                    }
                ]
                       
          Nothing ->
            div [] [h3 [] [text ("Search id: " ++ s.search_id)]]

    else
            div []
                [ p [] [ text "Search results are still not available (it may take 10-15 minutes)."]
                , p [] [ text ("You can wait at this page or you can lookup your search later at the home page by your current search id: " ++ s.search_id)]
                , p [] [ text "Current status is "
                       , Html.strong [] [ text (if s.status == "Ok" then "Submitted" else s.status) ]
                       , text "."
                       ]
                , p [] [ text "The page will refresh automatically every 5 seconds..." ]
                ]

viewSearchError : String -> Html Msg
viewSearchError err =
        div []
            [ Html.p [] [ Html.text "Call to the GMSC server failed" ]
            , Html.blockquote []
                [ Html.p [] [ Html.text err ] ]
            ]
