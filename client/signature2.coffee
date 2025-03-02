
crypto = require 'crypto'

# this is meant to be .wiki/status/owners.json, but any valid path with the correct json will work
idFile = process.argv.id || ''

expand = (text) ->
  text
    .replace /&/g, '&amp;'
    .replace /</g, '&lt;'
    .replace />/g, '&gt;'

page = ($item) ->
  $item.parents('.page').data('data')

check = ($item) ->
  # https://www.npmjs.com/package/object-hash ?
  # https://docs.nodejitsu.com/articles/cryptography/how-to-use-crypto-module/

  sum = crypto.createHash 'md5'
  for item in page($item).story
    if item.type == 'signature'
      sum.update item.text
    else
      sum.update JSON.stringify(item)
  sum.digest 'hex'

validateSignature = (sigObj) -> 
  console.log 'checking signature', sigObj
  algo = sigObj.algo
  
  switch algo
    when 'trivial' 
      return true
    when 'ecdsa'
      timestamp = sigObj.timestamp
      rev = sigObj.rev
      algo = sigObj.algo
      sum = sigObj.sum
      message = timestamp + rev + algo + sum
      signature = sigObj.signature
      fetch("/plugin/signature2/verify?signature=#{signature}&message=#{message}&pubKey=#{sigObj.pubKey}")
        .then (response) -> response.json()
        .then (result) -> result
      # return sessionless.verifySignature(signature, message, sigObj.pubKey)
      # here is where we get the signers' public keys
      # return true
    else
      null

emit = ($item, item) ->

  sum = check $item

  status = (sigs) ->
    console.log 'sum is', sum
    statusPromise = new Promise (resolve, reject) ->
      validateSignature(sigs[sum]).then (validated) ->
        if validated
          # "<td style=\"color: #3f3; text-align: right;\">valid"
          resolve "<td style=\"color: #f3f; text-align: left;\">valid"
        else
          resolve "<td style=\"color: #f88; text-align: left;\">invalid"

    statusPromise

  getKeys = ->
    getKeysPromise = new Promise (resolve, reject) ->
      fetches = []
      for site of item.signatures || {}
        encodedSite = encodeURIComponent site
        f = fetch('/plugin/signature2/owner-key?site=' + encodedSite)
          .then (resp) ->
            console.log 'received response from server', resp
            resp.json()
              .then (keyJSON) ->
                console.log 'keyJSON is', keyJSON
                console.log item.signatures
                console.log item.signatures[site]
                for sig of item.signatures[site]
                  pubKeyForSite = keyJSON.public
                  console.log item.signatures[site][sig]
                  if !item.signatures[site][sig]
                    continue
                  item.signatures[site][sig].pubKey = pubKeyForSite
              .catch (err) -> 
                console.warn 'this is actually the error', err
                throw new Error 'malformed json error'
          .catch (err) ->
            console.warn err

        fetches.push f

      Promise.all(fetches)
      .then(resolve)
      .catch(reject)

    getKeysPromise

  report = ->
    reportPromise = new Promise (resolve, reject) -> 
      statuses = []
      for site, sigs of item.signatures || {}
        signature = sigs[sum].signature
        status = status sigs
        # statuses.push("<tr>#{status sigs}<br>#{signature}<br>#{site}</td>")
        statuses.push status

      Promise.all(statuses).then (stats) ->
        resolve(stats)

    reportPromise

  getKeys()
    .then (keys) -> 
      console.log 'received keys', keys
      report()
    .then (statuses) ->
      console.log 'statuses are', statuses
      $item.append """
        <div style="background-color:#eee; padding:8px;">
          <center>
            #{expand item.text}
            <table style="background-color:#f8f8f8; margin:8px; padding:8px; min-width:70%">
              #{statuses.join('')}
            </table>
            <button class="sign">sign</button>
            # <button class="persist">persist</button>
            <a class="hiddenDownloadElement" style="display:none"></a>
          </center>
        </div>
      """
      bind $item, item

bind = ($item, item) ->
  console.log 'calling bind with $item', $item

  update = ->
    wiki.pageHandler.put $item.parents('.page:first'),
      type: 'edit',
      id: item.id,
      item: item

  $item.dblclick -> wiki.textEditor $item, item

  # $item.find('.persist').click ->
    # fetch('/plugin/signature2/persist').then (res) ->
      # res.json().then ($) ->
        # console.log "got response from server", $
        # if $.uuid
          # window.alert "PERSISTED! at #{$.uuid}"
        # console.log "should have alerted"

  $item.find('.sign').click ->
    console.log 'the button is getting clicked'
    date = new Date()
    timestamp = new Date().getTime() + ''
    rev = page($item).journal.length-1
#    algo = 'trivial'
    algo = 'ecdsa'
    sum = check $item
    host = location.host
    console.log 'signining sum', sum
    # sessionless.sign(timestamp + rev + algo + sum)
    fetch('/plugin/signature2/' + timestamp + rev + algo + sum)
      .then((res) -> 
        item.signatures ||= {}
        item.signatures[location.host] ||= {}
        return res.json()
      ).then((json) ->
        console.log 'json', json
        signature = json.signature
        item.signatures[location.host][sum] = {date, timestamp, rev, algo, sum, signature}
        console.log "signatures now has", item.signature[location.host][sum]
        $item.empty()
        emit $item, item
        bind $item, item
        update()
      ).catch((err) ->
        console.error('failure to sign message')
      )


window.plugins.signature2 = {emit, bind} if window?
module.exports = {expand} if module?

