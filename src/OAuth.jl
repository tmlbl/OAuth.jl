module OAuth

using HttpCommon, Requests, Nettle
import HttpCommon: encodeURI

export
oauth_timestamp,
oauth_nonce,
oauth_sign_hmac_sha1,
oauth_signing_key,
oauth_signature_base_string,
oauth_percent_encode_keys,
oauth_serialize_url_parameters,
encodeURI,
oauth_body_hash_file,
oauth_body_hash_data,
oauth_body_hash_encode,
oauth_header,
oauth_request_resource

#############################################################
#
# OAuth Client Functions
#
#############################################################

#Get current timestamp
function oauth_timestamp()
    "$(int(time()))"
end

#Generate random string
function oauth_nonce(length::Int64)
    randstring(length)
end

#HMAC-SHA1 sign message
function oauth_sign_hmac_sha1(message::String,signingkey::String)
    h = HMACState(SHA1, signingkey)
    update!(h, message)
    base64(digest!(h))
end

#Create signing key
function oauth_signing_key(oauth_consumer_secret::String, oauth_token_secret::String)
    "$(oauth_consumer_secret)&$(oauth_token_secret)"
end

#Create signature_base_string
function oauth_signature_base_string(httpmethod::String, url::String, parameterstring::String)
    "$(httpmethod)&$(encodeURI(url))&$(encodeURI(parameterstring))"
end

#URL-escape keys
function oauth_percent_encode_keys(options::Dict)
    #options encoded
    originalkeys = collect(keys(options))

    for key in originalkeys
        options[encodeURI("$key")] = encodeURI(options["$key"])
            if encodeURI("$key") != key
                delete!(options, "$key")
            end
    end

    options
end

#Create query string from dictionary keys
function oauth_serialize_url_parameters(options::Dict)
    #Sort keys
    keyssorted = sort!(collect(keys(options)))

    #Build query string, remove trailing &
    parameterstring = ""
    for key in keyssorted
        parameterstring *= "$key=$(options["$key"])&"
    end

    chop(parameterstring)
end

#Extend encodeURI from HttpCommon to work on Dicts
function encodeURI(dict_of_parameters::Dict)
    for (k, v) in dict_of_parameters
        if typeof(v) <: String
            dict_of_parameters["$k"] = encodeURI(v)
        else
            dict_of_parameters["$k"] = v
        end
    end
    return dict_of_parameters
end

#Combine with oauth_body_hash_file as one function with two methods?
function oauth_body_hash_file(filename::String)
    filecontents =  readall(open(filename))
    oauth_body_hash_data(filecontents)
end

#Combine with oauth_body_hash_file as one function with two methods?
function oauth_body_hash_data(data::String)
    bodyhash = oauth_body_hash_encode(data)
    "oauth_body_hash=$(bodyhash)"
end

#Use functions from Nettle
function oauth_body_hash_encode(data::String)
        h = HashState(SHA1)
        update!(h, data)
        base64(digest!(h))
end

#Use this function to build the header for every OAuth call
#This function assumes that options Dict has already been run through encodeURI
#Use this function to build the header for every OAuth call
#This function assumes that options Dict has already been run through encodeURI
function oauth_header(httpmethod, baseurl, options, oauth_consumer_key, oauth_consumer_secret, oauth_token, oauth_token_secret;
                     oauth_signature_method = "HMAC-SHA1",
                     oauth_version = "1.0")

    #keys for parameter string
    options["oauth_consumer_key"] = oauth_consumer_key
    options["oauth_nonce"] = oauth_nonce(32)
    options["oauth_signature_method"] = oauth_signature_method
    options["oauth_timestamp"] = oauth_timestamp()
    options["oauth_token"] = oauth_token
    options["oauth_version"] = oauth_version

    #options encoded
    options = oauth_percent_encode_keys(options)

    #Create ordered query string
    parameterstring = oauth_serialize_url_parameters(options)

    #Calculate signature_base_string
    signature_base_string = oauth_signature_base_string(uppercase(httpmethod), baseurl, parameterstring)

    #Calculate signing_key
    signing_key = oauth_signing_key(oauth_consumer_secret, oauth_token_secret)

    #Calculate oauth_signature
    oauth_sig = encodeURI(oauth_sign_hmac_sha1(signature_base_string, signing_key))

    return "OAuth oauth_consumer_key=\"$(options["oauth_consumer_key"])\", oauth_nonce=\"$(options["oauth_nonce"])\", oauth_signature=\"$(oauth_sig)\", oauth_signature_method=\"$(options["oauth_signature_method"])\", oauth_timestamp=\"$(options["oauth_timestamp"])\", oauth_token=\"$(options["oauth_token"])\", oauth_version=\"$(options["oauth_version"])\""

end

function oauth_request_resource(endpoint::String, httpmethod::String, options::Dict, oauth_consumer_key::String, oauth_consumer_secret::String, oauth_token::String, oauth_token_secret::String)

    #Build query string
    query_str = Requests.format_query_str(options)

    #Build oauth_header
    #oauth_header_val = oauth_header(httpmethod, endpoint, options)
    oauth_header_val = oauth_header(httpmethod, endpoint, options, oauth_consumer_key, oauth_consumer_secret, oauth_token, oauth_token_secret)

    #Make request
    if uppercase(httpmethod) == "POST"
        return Requests.post(URI(endpoint),
                        query_str;
                        headers =
                        Dict("Content-Type" => "application/x-www-form-urlencoded",
                        "Authorization" => oauth_header_val,
                        "Accept" => "*/*"))

    elseif uppercase(httpmethod) == "GET"
        return Requests.get(URI("$(endpoint)?$query_str");
                        headers =
                        Dict("Content-Type" => "application/x-www-form-urlencoded",
                        "Authorization" => oauth_header_val,
                        "Accept" => "*/*"))
    end

end

end # module
