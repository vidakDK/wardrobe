module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Element exposing (..)
import Element.Border as Border
import Element.Input as Input
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Url
import Url.Builder as Builder



-- MAIN


main : Program Decode.Value Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- MODEL


type alias Api =
    { all : String
    , addItem : String
    }


type alias ClothingItem =
    { id : Int
    , color : String
    , name : String
    }


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , api : Api
    , user : String
    , clothes : List ClothingItem
    , colorInput : String
    , nameInput : String
    }


type FormInput
    = Color
    | Name


init : Decode.Value -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flagsJson url key =
    let
        api =
            case Decode.decodeValue apiDecoder flagsJson of
                Ok decodedApi ->
                    decodedApi

                Err error ->
                    Debug.log (Decode.errorToString error) (Api "" "")
    in
    ( Model key
        url
        api
        "Raul"
        -- clothing items
        []
        -- colorInput
        ""
        -- nameInput
        ""
    , requestClothes api.all "raul"
    )


requestClothes : String -> String -> Cmd Msg
requestClothes url userId =
    Http.get
        { url = Builder.relative [ url ] [ Builder.string "user" userId ]
        , expect = Http.expectJson ClothesLoaded clothingItemsDecoder
        }


addItem : String -> String -> { color : String, name : String } -> Cmd Msg
addItem url userId item =
    Http.post
        { url = Builder.relative [ url ] [ Builder.string "user" userId ]
        , body = Http.jsonBody (itemEncoder item)
        , expect = Http.expectJson ItemAdded (itemDecoder item)
        }


apiDecoder : Decode.Decoder Api
apiDecoder =
    Decode.map2 Api
        (Decode.at [ "api", "all" ] Decode.string)
        (Decode.at [ "api", "add_item" ] Decode.string)


clothingItemsDecoder : Decode.Decoder (List ClothingItem)
clothingItemsDecoder =
    Decode.field "data" <|
        Decode.list <|
            Decode.map3 ClothingItem
                (Decode.field "id" Decode.int)
                (Decode.field "color" Decode.string)
                (Decode.field "name" Decode.string)


itemDecoder : { color : String, name : String } -> Decode.Decoder ClothingItem
itemDecoder item =
    Decode.field "data" <|
        Decode.map3 ClothingItem
            (Decode.field "id" Decode.int)
            (Decode.succeed item.color)
            (Decode.succeed item.name)


itemEncoder : { color : String, name : String } -> Encode.Value
itemEncoder item =
    Encode.object
        [ ( "data"
          , Encode.object
                [ ( "color", Encode.string item.color )
                , ( "name", Encode.string item.name )
                ]
          )
        ]



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | ClothesLoaded (Result Http.Error (List ClothingItem))
    | TypedInput FormInput String
    | AddPressed
    | ItemAdded (Result Http.Error ClothingItem)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( { model | url = url }
            , Cmd.none
            )

        ClothesLoaded result ->
            case result of
                Ok items ->
                    ( { model | clothes = items }, Cmd.none )

                Err error ->
                    ( model, Cmd.none )

        TypedInput inputType inputValue ->
            case inputType of
                Color ->
                    ( { model | colorInput = inputValue }, Cmd.none )

                Name ->
                    ( { model | nameInput = inputValue }, Cmd.none )

        AddPressed ->
            ( model
            , addItem model.api.addItem
                "raul"
                { color = model.colorInput
                , name = model.nameInput
                }
            )

        ItemAdded result ->
            case result of
                Ok item ->
                    ( { model | clothes = item :: model.clothes }, Cmd.none )

                Err error ->
                    ( model, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


colors =
    { royalBlue = rgb 0.25 0.41 0.88
    , black = rgb 0.1 0.1 0.1
    }


view : Model -> Browser.Document Msg
view model =
    let
        subtitle =
            case model.user of
                "" ->
                    "Nobody's clothes"

                _ ->
                    model.user ++ "'s clothes"
    in
    Browser.Document "Wardrobe"
        [ layout [] <|
            column []
                [ text "My Clothes"
                , viewForm model.colorInput model.nameInput
                , text subtitle
                , column [] (List.map viewItem model.clothes)
                ]
        ]


viewForm : String -> String -> Element Msg
viewForm colorInput nameInput =
    let
        viewPlaceholder placeholder =
            Just (Input.placeholder [] (text placeholder))
    in
    row []
        [ Input.text []
            { onChange = TypedInput Color
            , text = colorInput
            , placeholder = viewPlaceholder "enter a color"
            , label = Input.labelAbove [] (text "color")
            }
        , Input.text []
            { onChange = TypedInput Name
            , text = nameInput
            , placeholder = viewPlaceholder "enter a name"
            , label = Input.labelAbove [] (text "name")
            }
        , Input.button [ Border.width 1, Border.color colors.black ]
            { onPress = Just AddPressed
            , label = text "Add Item"
            }
        ]


viewItem : ClothingItem -> Element msg
viewItem item =
    row []
        [ text
            (String.join " "
                [ String.fromInt item.id ++ ":"
                , item.color
                , item.name
                ]
            )
        ]



--view model =
--    { title = "URL Interceptor"
--    , body =
--        [ text "The current URL is: "
--        , b [] [ text (Url.toString model.url) ]
--        , ul []
--            [ viewLink "/home"
--            , viewLink "/profile"
--            , viewLink "/reviews/the-century-of-the-self"
--            , viewLink "/reviews/public-opinion"
--            , viewLink "/reviews/shah-of-shahs"
--            ]
--        ]
--    }
--viewLink : String -> Html msg
--viewLink path =
--    li [] [ a [ href path ] [ text path ] ]
