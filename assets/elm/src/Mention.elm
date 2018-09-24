module Mention exposing (Mention, decoder, fragment)

import GraphQL exposing (Fragment)
import Json.Decode as Decode exposing (Decoder, field, maybe)
import Reply exposing (Reply)
import SpaceUser exposing (SpaceUser)
import Time exposing (Posix)
import Util exposing (dateDecoder)



-- TYPES


type Mention
    = Mention Data


type alias Data =
    { mentioner : SpaceUser
    , reply : Maybe Reply
    , occurredAt : Posix
    }


fragment : Fragment
fragment =
    GraphQL.toFragment
        """
        fragment MentionFields on Mention {
          mentioner {
            ...SpaceUserFields
          }
          reply {
            ...ReplyFields
          }
          occurredAt
        }
        """
        [ SpaceUser.fragment
        , Reply.fragment
        ]



-- DECODERS


decoder : Decoder Mention
decoder =
    Decode.map Mention <|
        Decode.map3 Data
            (field "mentioner" SpaceUser.decoder)
            (field "reply" (maybe Reply.decoder))
            (field "occurredAt" dateDecoder)
