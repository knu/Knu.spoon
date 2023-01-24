local http = {}

local fnutils = hs.fnutils
local utils = require((...):gsub("[^.]+$", "utils"))

-- This is a wrapperr of hs.http.urlParts() that adds a "params" table
-- and lowercases the "scheme" and "host" fields.
http.urlParts = function (url)
  local uri = hs.http.urlParts(url)
  if uri.scheme ~= nil then
    uri.scheme = uri.scheme:lower()
  end
  if uri.host ~= nil then
    uri.host = uri.host:lower()
  end
  local params = {}
  if uri.queryItems ~= nil then
    for _, t in ipairs(uri.queryItems) do
      for k, v in pairs(t) do
        params[k] = v
      end
    end
  end
  uri.params = params
  return uri
end

http.shortenerHosts = {
  "amzn.to",
  "bit.ly",
  "bl.ink",
  "buff.ly",
  "db.tt",
  "dlvr.it",
  "fb.me",
  "g.co",
  "gg.gg",
  "goo.gl",
  "ht.ly",
  "ift.tt",
  "is.gd",
  "j.mp",
  "m.me",
  "ow.ly",
  "rebrand.ly",
  "t.co",
  "t.ly",
  "tiny.cc",
  "tinyurl.com",
  "url.ie",
  "v.gd",
  "wp.me",
  "yhoo.it",
  "zpr.io",
}

-- Unshortens the given URL.  Returns the unshortened URL followed by
-- nil or an error message if it fails.  Failures include too many
-- recursive redirects, HTTP errors, etc.  http.shortenerHosts is a
-- table of known shortener hosts.  This function does not try to
-- follow redirects of a URL with a host name that is not on this
-- list.
http.unshortenURL = function(url)
  local purl = url
  local nurl = url
  local count = 0

  while nurl ~= nil do
    local uri = hs.http.urlParts(nurl)
    if uri.scheme ~= "https" and uri.scheme ~= "http" then
      return purl, "non-HTTP scheme"
    elseif uri.host == nil then
      return purl, "host is missing"
    end
    local host = uri.host:lower()
    if fnutils.indexOf(http.shortenerHosts, host) == nil then
      return nurl, nil
    end
    if count >= 3 then
      return nurl, "too many redirects"
    end
    count = count + 1
    purl = nurl

    local output, ok = hs.execute(
      utils.shelljoin{
        "curl",
        "-s",
        "-I",
        "-o",
        "/dev/null",
        "-w",
        "%{http_code} %header{location}",
        nurl,
      }
    )
    if not ok then
      return nurl, "curl failed"
    end
    local status, location = table.unpack(fnutils.split(output, " ", 1))
    if status >= "400" then
      return nurl, "HTTP error " .. status
    elseif status >= "300" and location and #location > 0 then
      nurl = location
    else
      -- not a redirect
      return nurl, nil
    end
  end
  return purl, "invalid URL"
end

return http