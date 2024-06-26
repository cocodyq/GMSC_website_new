module Browse exposing (Model, Msg(..), initialModel, update, viewModel)

import Html exposing (..)
import Html.Attributes as HtmlAttr
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Browser
import Dict
import Set
import Markdown
import View exposing (View)

import Bootstrap.CDN as CDN
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.Button as Button
import Bootstrap.ButtonGroup as ButtonGroup
import Bootstrap.Form as Form
import Bootstrap.Form.Select as Select
import Bootstrap.Form.Input as Input
import Bootstrap.Form.InputGroup as InputGroup
import Bootstrap.Form.Textarea as Textarea
import Bootstrap.Dropdown as Dropdown
import Bootstrap.Card as Card
import Bootstrap.Text as Text
import Bootstrap.Card.Block as Block
import Bootstrap.Popover as Popover
import Bootstrap.Form.Checkbox as Checkbox

import Filter
import Selects
import Selectshared
import Shared
import Selectitem

stringFromBool : Bool -> String
stringFromBool value =
  if value then
    "True"
  else
    "False"

trueFromPass : String -> String
trueFromPass value = 
  if value == "Pass"
    then "True"
  else if value == ""
    then ""
  else
    "False"

habitatItem : Model -> String
habitatItem model =
  String.join "," <| List.sort (Set.toList ( Set.fromList ( List.map model.selectpost.habitatSearch.itemToLabel model.selectpost.habitatSearch.selected )))
  
taxItem : Model -> String
taxItem model =
  String.join "," <| List.map model.selectpost.taxonomySearch.itemToLabel model.selectpost.taxonomySearch.selected

antifamItem : Model -> String
antifamItem model =
  trueFromPass (String.join "," <| List.map model.selectpost.antifamSearch.itemToLabel model.selectpost.antifamSearch.selected)

terminalItem : Model -> String
terminalItem model =
  trueFromPass (String.join "," <| List.map model.selectpost.terminalSearch.itemToLabel model.selectpost.terminalSearch.selected)

rnaCode : String -> String
rnaCode val =
    if val == "10"
        then "1.0"
    else if val == "9"
        then "0.1"
    else if val == "8"
        then "0.05"
    else if val == "7"
        then "0.01"
    else if val == "6"
        then "0.005"
    else if val == "5"
        then "0.001"
    else if val == "4"
        then "0.0005"
    else if val == "3"
        then "0.0001"
    else if val == "2"
        then "0.00005"
    else if val == "1"
        then "0.00001"
    else if val == "0"
        then "0.0"
    else
        ""

metaP : String -> String
metaP val = 
    String.fromFloat ((Maybe.withDefault 0 (String.toFloat val))/100)   
 
type OperationType = All 
                    | HQ 
                    | Advanced

type alias SelectModel =
    { habitatSearch : Selectshared.Model Selectitem.Habitat
    , taxonomySearch : Selectshared.Model Selectitem.Taxonomy
    , antifamSearch : Selectshared.Model Selectitem.Antifam
    , terminalSearch : Selectshared.Model Selectitem.Terminal
    }

type alias Model =
    { selectpost : SelectModel
    , filterpost : Filter.Model
    , ask: Bool
    , popoverState1 : Popover.State
    , popoverState2 : Popover.State
    , rnacodecontent : String
    , metatcontent : String
    , riboseqcontent : String
    , metapcontent : String
    , hq: String
    , optype : OperationType
    }

type Msg 
    = Search
    | FilterMsg Filter.Msg
    | HabitatSearchMsg (Selectshared.Msg Selectitem.Habitat)
    | TaxonomySearchMsg (Selectshared.Msg Selectitem.Taxonomy)
    | AntifamSearchMsg (Selectshared.Msg Selectitem.Antifam)
    | TerminalSearchMsg (Selectshared.Msg Selectitem.Terminal)
    | NoOp
    | PopoverMsg1 Popover.State
    | PopoverMsg2 Popover.State
    | SetRnacode String
    | SetmetaT String
    | SetRiboseq String
    | SetmetaP String
    | SelectOp OperationType

initialModel : (Model, Cmd Msg)
initialModel =
    let
        (sm, cmd) = Filter.initialState "" "" "" "" "" "" "" "" ""
    in
        ({ selectpost = { habitatSearch = Selectshared.initialModel 
                               { id = "exampleMulti"
                               , available = Selectitem.habitats
                               , itemToLabel = Selectitem.habitattoLabel
                               , selected = [ ]
                               , selectConfig = selectConfigHabitatSearch
                               }
                        , taxonomySearch = Selectshared.initialModel 
                               { id = "exampleEmptySearch"
                               , available = Selectitem.taxonomy
                               , itemToLabel = Selectitem.taxtoLabel
                               , selected = [ ]
                               , selectConfig = selectConfigTaxonomySearch
                               }
                        , antifamSearch = Selectshared.initialModel 
                               { id = "exampleEmptySearch"
                               , available = Selectitem.antifam
                               , itemToLabel = Selectitem.antifamtoLabel
                               , selected = [ ]
                               , selectConfig = selectConfigAntifamSearch
                               }
                        , terminalSearch = Selectshared.initialModel 
                               { id = "exampleEmptySearch"
                               , available = Selectitem.terminal
                               , itemToLabel = Selectitem.terminaltoLabel
                               , selected = [ ]
                               , selectConfig = selectConfigTerminalSearch
                               }
                        }
        , filterpost = sm
        , ask = False
        , popoverState1 = Popover.initialState
        , popoverState2 = Popover.initialState
        , rnacodecontent = ""
        , metatcontent = ""
        , riboseqcontent = ""
        , metapcontent = ""
        , hq = ""
        , optype = All
        }
        , Cmd.map FilterMsg cmd
        )


update : Msg -> Model -> ( Model, Cmd Msg)
update msg model =
    let
        ifQuery f = 
                let
                    (qmpost, c) = f model.selectpost
                in ({model| selectpost = qmpost}, c)
    in case msg of
        NoOp ->
            ( model, Cmd.none )
        
        PopoverMsg1 state ->
            ( { model | popoverState1 = state }, Cmd.none )

        PopoverMsg2 state ->
            ( { model | popoverState2 = state }, Cmd.none )

        HabitatSearchMsg sub ->
            ifQuery <| \qmodel ->
              let
                ( subModel, subCmd ) =
                    Selectshared.update sub qmodel.habitatSearch
              in
                ({ qmodel | habitatSearch = subModel }
                , Cmd.map HabitatSearchMsg subCmd
                )
        TaxonomySearchMsg sub ->
            ifQuery <| \qmodel ->
              let
                ( subModel, subCmd ) =
                    Selectshared.update sub qmodel.taxonomySearch
              in
                ({ qmodel | taxonomySearch = subModel }
                , Cmd.map TaxonomySearchMsg subCmd
                )

        AntifamSearchMsg sub ->
            ifQuery <| \qmodel ->
              let
                ( subModel, subCmd ) =
                    Selectshared.update sub qmodel.antifamSearch
              in
                ({ qmodel | antifamSearch = subModel }
                , Cmd.map AntifamSearchMsg subCmd
                )

        TerminalSearchMsg sub ->
            ifQuery <| \qmodel ->
              let
                ( subModel, subCmd ) =
                    Selectshared.update sub qmodel.terminalSearch
              in
                ({ qmodel | terminalSearch = subModel }
                , Cmd.map TerminalSearchMsg subCmd
                )

        SetRnacode p ->
            ( { model | rnacodecontent = p }, Cmd.none )

        SetmetaT number ->
            ( { model | metatcontent = number }, Cmd.none )  

        SetRiboseq number ->
            ( { model | riboseqcontent = number }, Cmd.none )  

        SetmetaP cov ->
            ( { model | metapcontent = cov}, Cmd.none )      

        Search ->
            if  habitatItem model == "" &&
                taxItem model == "" &&
                antifamItem model == "" &&
                terminalItem model == "" &&
                model.rnacodecontent == "" &&
                model.metatcontent == "" &&
                model.riboseqcontent == "" &&
                model.metapcontent == "" &&
                model.hq == "" then
                (model, Cmd.none) 
            else
                let
                    (sm, cmd) = Filter.initialState 
                                    (habitatItem model) 
                                    (taxItem model) 
                                    (antifamItem model) 
                                    (terminalItem model) 
                                    (rnaCode model.rnacodecontent)
                                    model.metatcontent 
                                    model.riboseqcontent 
                                    (metaP model.metapcontent)
                                    model.hq
                in ({ model| filterpost = sm, ask=True }, Cmd.map FilterMsg cmd)

        FilterMsg m -> 
            let
                (nqm, cmd) = Filter.update m model.filterpost
            in
                ({ model| filterpost = nqm }, Cmd.map FilterMsg cmd)

        SelectOp p ->
            if model.optype == All && p == HQ 
                then ( { model | optype = HQ , hq = "True", rnacodecontent = "", metatcontent = "", riboseqcontent = "", metapcontent = ""}, Cmd.none )
            else if model.optype == All && p == Advanced 
                then ( { model | optype = Advanced , hq = "False", rnacodecontent = "8", metatcontent = "2", riboseqcontent = "2", metapcontent = "50" }, Cmd.none )
            else if model.optype == HQ && p == All 
                then ( { model | optype = All, hq = "False", rnacodecontent = "", metatcontent = "", riboseqcontent = "", metapcontent = "" }, Cmd.none )
            else if model.optype == HQ && p == Advanced 
                then ( { model | optype = Advanced, hq = "False", rnacodecontent = "8", metatcontent = "2", riboseqcontent = "2", metapcontent = "50" }, Cmd.none )
            else if model.optype == Advanced && p == All 
                then ( { model | optype = All, hq = "False", rnacodecontent = "", metatcontent = "", riboseqcontent = "", metapcontent = "" }, Cmd.none )
            else if model.optype == Advanced && p == HQ 
                then ( { model | optype = HQ, hq = "True", rnacodecontent = "", metatcontent = "", riboseqcontent = "", metapcontent = "" }, Cmd.none )
            else
                ( { model | optype = p }, Cmd.none )

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none

viewModel : Model -> Html Msg
viewModel model =
    case model.filterpost.showpost of
    Filter.SLoading ->
        if model.ask then
            div [] 
                [ viewSearch model
                , Html.hr [] []
                , Filter.viewModel model.filterpost
                    |> Html.map FilterMsg
                ]
        else
            div [] 
                [ viewSearch model
                ]
    Filter.MultiResults r ->
        div [] 
            [ viewSearch model
            , Html.hr [] []
            , Filter.viewModel model.filterpost
                |> Html.map FilterMsg
            ]
    _ ->
        div []
            [ viewSearch model ]

viewSearch: Model -> Html Msg
viewSearch model = div []
        [ h5 [] [ text "Browse by habitats and taxonomy "] 
        , div [] [ p [] [ label [id "browse"] [ text "Browse by habitats " 
                                              , Popover.config
                                               ( Button.button
                                                   [ Button.small
                                                   , Button.outlineInfo
                                                   , Button.attrs <|
                                                       Popover.onHover model.popoverState2 PopoverMsg2
                                                   ]
                                                   [ span [class "fa fa-question-circle"]
                                                   []
                                                   ]
                                               )
                                               |> Popover.right
                                               |> Popover.content []
                                                      [ text "Habitats with the suffix 'associated' represent a wider range of environments that cannot be traced further to more specific habitats. For example, 'human associated' represents human related habitats other than those listed in 'gut', 'south', etc." ]
                                               |> Popover.view model.popoverState2] ] ]
        , div [] 
            [ Selectshared.view
              model.selectpost.habitatSearch
              |> Html.map HabitatSearchMsg 
            ]
        , div [] [ p [] [ label [id "browse"] [ text "Browse by taxonomy" ] ] ]
        , div [] 
            [ Selectshared.view
              model.selectpost.taxonomySearch
              |> Html.map TaxonomySearchMsg
            ]
        , h5 [] [ text "Browse by quality"]
        , viewHq model
        , if model.optype == All
            then p [] [ text "" ]
          else if model.optype == HQ
            then p [] [ text "" ]
          else
            viewSpecific model
        , div [class "browse"] [Button.button [ Button.info, Button.onClick Search] [ text "Browse" ]]
        ]

selectConfigHabitat =
    Selects.newConfig
        { onSelect = Selectshared.OnSelect
        , toLabel = Selectitem.habitattoLabel
        , filter = Shared.filter 1 Selectitem.habitattoLabel
        , toMsg = Selectshared.SelectMsg
        }

selectConfigHabitatSearch =
    selectConfigHabitat
        |> Selects.withMultiSelection True
        |> Selects.withOnRemoveItem Selectshared.OnRemoveItem
        -- |> Selects.withCutoff 12
        |> Selects.withEmptySearch True
        |> Selects.withNotFound "No matches"
        |> Selects.withPrompt "Select habitats"

selectConfigTaxonomySearch =
    Selects.newConfig
        { onSelect = Selectshared.OnSingleSelect
        , toLabel = .label
        , filter = Shared.filter 1 .label
        , toMsg = Selectshared.SelectMsg
        }
        -- |> Selects.withCutoff 12
        |> Selects.withEmptySearch True
        |> Selects.withNotFound "No matches"
        |> Selects.withPrompt "Select taxonomy"

selectConfigAntifamSearch =
    Selects.newConfig
        { onSelect = Selectshared.OnSingleSelect
        , toLabel = .label
        , filter = Shared.filter 1 .label
        , toMsg = Selectshared.SelectMsg
        }
        -- |> Selects.withCutoff 12
        |> Selects.withEmptySearch True
        |> Selects.withNotFound "No matches"
        |> Selects.withPrompt "Pass / Fail"

selectConfigTerminalSearch =
    Selects.newConfig
        { onSelect = Selectshared.OnSingleSelect
        , toLabel = .label
        , filter = Shared.filter 1 .label
        , toMsg = Selectshared.SelectMsg
        }
        -- |> Selects.withCutoff 12
        |> Selects.withEmptySearch True
        |> Selects.withNotFound "No matches"
        |> Selects.withPrompt "Pass / Fail"

viewHq : Model -> Html Msg
viewHq model =  
  let
    buttonStyle who active =
        [ if who == active then Button.info else Button.outlineInfo, Button.onClick (SelectOp who) ]
  in div [class "buttonselect"] 
    [ Form.form []
        [ Form.row []
            [ Form.col [ Col.sm10 ]
                [ ButtonGroup.buttonGroup [ ButtonGroup.small ]
                    [ ButtonGroup.button (buttonStyle All model.optype) [ text "Show all" ]
                    , ButtonGroup.button (buttonStyle HQ model.optype) [ text "Only show high quality" ]
                    , ButtonGroup.button (buttonStyle Advanced model.optype) [ text "Advanced quality filtering" ]
                    ]
                ]
            ]
        ]
    ]              

viewSpecific : Model -> Html Msg
viewSpecific model =  
    div []
        [ p [] [ em [] [text "Note that using quality filters can be slow" ]]
        , div [] [ p [] [ label [ id "quality" ] [ text "Antifam filtering" ] ] ]
        , div [ class "dropdown" ] 
            [ Selectshared.view
              model.selectpost.antifamSearch
              |> Html.map AntifamSearchMsg
            ]
        , div [] [ p [] [ label [ id "quality" ] [ text "Terminal checking" ] ] ]
        , div [ class "dropdown" ]
            [ Selectshared.view
              model.selectpost.terminalSearch
              |> Html.map TerminalSearchMsg
            ]
        , div [ class "browse" ] [ Form.form []
                    [ Form.group []
                        [ Form.label [ id "quality" ] [ text "P-value for RNAcode threshold (default: 0.05)" ]
                        , Form.help [] [ text "" ]
                        , input
                            [ type_ "range"
                            , HtmlAttr.value model.rnacodecontent
                            , HtmlAttr.min "0"
                            , HtmlAttr.max "10"
                            , HtmlAttr.step "1"
                            , onInput SetRnacode
                            ] []
                        , text <| " (" ++ rnaCode model.rnacodecontent ++ ")"
                        ]
                    ]
                  ]
        , div [ class "browse" ] [ Form.form []
                    [ Form.group []
                        [ Form.label [id "quality"] [ text "Minimum number of metatranscriptome hits (default: 2)" ]
                        , Form.help [] [ text "" ]
                        , input
                            [ type_ "range"
                            , HtmlAttr.value model.metatcontent
                            , HtmlAttr.min "0"
                            , HtmlAttr.max "221"
                            , HtmlAttr.step "1"
                            , onInput SetmetaT
                            ] []
                        , text <| " (" ++ model.metatcontent ++ ")"
                        ]
                    ]
                  ]
        , div [ class "browse" ] [ Form.form []
                    [ Form.group []
                        [ Form.label [ id "quality" ] [ text "Minimum number of Riboseq hits (default: 2)" ]
                        , Form.help [] [ text "" ]
                        , input
                            [ type_ "range"
                            , HtmlAttr.value model.riboseqcontent
                            , HtmlAttr.min "0"
                            , HtmlAttr.max "142"
                            , HtmlAttr.step "1"
                            , onInput SetRiboseq
                            ] []
                        , text <| " (" ++ model.riboseqcontent ++ ")"
                        ]
                    ]
                  ]
        , div [ class "browse" ] [ Form.form []
                    [ Form.group []
                        [ Form.label [ id "quality" ] [ text "Minimum smORF coverage in metaproteomics (default: 50%)" ]
                        , Form.help [] [ text "" ]
                        , input
                            [ type_ "range"
                            , HtmlAttr.value model.metapcontent
                            , HtmlAttr.min "0"
                            , HtmlAttr.max "100"
                            , HtmlAttr.step "1"
                            , onInput SetmetaP
                            ] []
                        , text <| " (" ++ model.metapcontent ++ "%)"
                        ]
                    ]
                  ]
    ]
