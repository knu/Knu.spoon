local http = {}

local fnutils = hs.fnutils
local knu = hs.loadSpoon("Knu")
local utils = knu.utils

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
  "a.co",
  "amzn.to",
  "bit.ly",
  "bitly.com",
  "bl.ink",
  "buff.ly",
  "cutt.ly",
  "db.tt",
  "dlvr.it",
  "fb.me",
  "ffm.to",
  "g.co",
  "geni.us",
  "gg.gg",
  "goo.gl",
  "ht.ly",
  "ift.tt",
  "is.gd",
  "j.mp",
  "lnk.to",
  "m.me",
  "ow.ly",
  "rebrand.ly",
  "shorturl.at",
  "smarturl.it",
  "t.co",
  "t.ly",
  "tiny.cc",
  "tinyurl.com",
  "url.ie",
  "v.gd",
  "wp.me",
  "yhoo.it",
  "zpr.io",
  -- affiliate redirectors
  "anrdoezrs.net",
  "click.linksynergy.com",
  "dpbolvw.net",
  "fave.co",
  "go.redirectingat.com",
  "go.skimresources.com",
  "jdoqocy.com",
  "kqzyfj.com",
  "rstyle.me",
  "shopstyle.it",
  "tkqlhce.com",
  -- tracking links
  "ct.sendgrid.net",
  "hubspotlinks.com",
  "list-manage.com",
  "r.mailjet.com",
}

-- Hosts that wrap a destination URL in a query parameter (or in the
-- raw query string).  Each entry has:
--   host:   a host name or a Lua pattern (anchored with ^).  A plain
--           string also matches any subdomain.
--   path:   optional path prefix that must match.
--   params: list of query parameter names to try in order; the first
--           one with a non-empty value is used as the target URL.
--           The special name "?" means the entire raw query string.
http.redirectorHosts = {
  { host = "l.facebook.com",        params = {"u"} },
  { host = "lm.facebook.com",       params = {"u"} },
  { host = "^www%.google%.[%a.]+$", path = "/url",        params = {"q", "url"} },
  { host = "^google%.[%a.]+$",      path = "/url",        params = {"q", "url"} },
  { host = "href.li",               params = {"?"} },
  { host = "l.instagram.com",       params = {"u"} },
  { host = "l.messenger.com",       params = {"u"} },
  { host = "out.reddit.com",        params = {"url"} },
  { host = "click.redditmail.com",  params = {"url"} },
  { host = "steamcommunity.com",    path = "/linkfilter", params = {"url"} },
  { host = "t.umblr.com",           params = {"z"} },
  { host = "away.vk.com",           params = {"to"} },
  { host = "l.wl.co",               params = {"u"} },
  { host = "youtube.com",           path = "/redirect",   params = {"q"} },
}

local function hostMatches(host, pattern)
  if pattern:sub(1, 1) == "^" then
    return host:match(pattern) ~= nil
  end
  return host == pattern or utils.string.endsWith(host, "." .. pattern)
end

local function urldecode(s)
  return (s:gsub("+", " "):gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

-- Unwraps a single layer of redirector wrapping.  Returns the
-- unwrapped URL followed by nil on success, or the original URL
-- followed by a reason if the URL is not a known redirector or
-- cannot be unwrapped.  Does not perform any network access and
-- does not recurse.
http.unwrapUrl = function(url)
  local uri = http.urlParts(url)
  if uri.scheme ~= "http" and uri.scheme ~= "https" then
    return url, "non-HTTP scheme"
  end
  if uri.host == nil then
    return url, "host is missing"
  end
  local path = uri.path or ""

  for _, rule in ipairs(http.redirectorHosts) do
    if hostMatches(uri.host, rule.host) and (rule.path == nil or utils.string.startsWith(path, rule.path)) then
      local target
      for _, name in ipairs(rule.params) do
        local v
        if name == "?" then
          v = uri.query
        else
          v = uri.params[name]
        end
        if v ~= nil and v ~= "" then
          target = v
          break
        end
      end
      if target == nil or target == "" then
        return url, "no target parameter"
      end
      local decoded = urldecode(target)
      local targetUri = hs.http.urlParts(decoded)
      if targetUri.scheme == nil then
        return url, "target is not an absolute URL"
      end
      local targetScheme = targetUri.scheme:lower()
      if targetScheme ~= "http" and targetScheme ~= "https" then
        return url, "target has non-HTTP scheme"
      end
      return decoded, nil
    end
  end
  return url, "not a known redirector"
end

-- Unshortens the given URL.  Returns the unshortened URL followed by
-- nil or an error message if it fails.  Failures include too many
-- recursive redirects, HTTP errors, etc.  http.shortenerHosts is a
-- table of known shortener hosts.  This function does not try to
-- follow redirects of a URL with a host name that is not on this
-- list.
--
-- Options:
--   unwrap: if true, recursively unwrap known redirector URLs
--           (see http.redirectorHosts) before and after each
--           shortener resolution.
http.unshortenUrl = function(url, options)
  options = options or {}
  local purl = url
  local nurl = url
  local count = 0
  local logger = hs.logger.new("unshorten", "info")

  local function unwrapAll(u)
    while true do
      local unwrapped, err = http.unwrapUrl(u)
      if err ~= nil then
        return u
      end
      u = unwrapped
    end
  end

  if options.unwrap then
    nurl = unwrapAll(nurl)
    purl = nurl
  end

  while nurl ~= nil do
    local uri = hs.http.urlParts(nurl)
    if uri.scheme ~= "https" and uri.scheme ~= "http" then
      return purl, "non-HTTP scheme"
    elseif uri.host == nil then
      return purl, "host is missing"
    end
    local host = uri.host:lower()
    local isShortener = false
    if uri.path == "/ls/click" and
      uri.query ~= nil and utils.string.startsWith(uri.query, "upn=") then
      isShortener = true
    else
      for _, domain in ipairs(http.shortenerHosts) do
        if host == domain or utils.string.endsWith(host, "." .. domain) then
          isShortener = true
          break
        end
      end
    end
    if not isShortener then
      return nurl, nil
    end
    logger.i(host)
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
      if options.unwrap then
        nurl = unwrapAll(nurl)
      end
    else
      -- not a redirect
      return nurl, nil
    end
  end
  return purl, "invalid URL"
end

return http
