
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
      # return sessionless.verifySignature(signature, message, keys.pubKey)
      # here is where we get the signers' public keys
      return true
    else
      null

emit = ($item, item) ->

  sum = check $item

  status = (sigs) ->
    console.log 'sum is', sum
    if validateSignature sigs[sum]
      # "<td style=\"color: #3f3; text-align: right;\">valid"
     "<td style=\"color: #f3f; text-align: left;\">valid"
    else
      "<td style=\"color: #f88; text-align: left;\">invalid"

  getKeys = ->
    getKeysPromise = new Promise (resolve, reject) ->
      fetches = []
      for site of item.signatures || {}
        f = fetch(site + '/wiki/plugin/security/key').then (key) ->
          for sigs of item.signatures[site]
            sigs[sum].pubKey = pubKeyForSite

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
        statuses.push("<tr>#{status sigs}<br>#{signature}<br>#{site}</td>")
      resolve(statuses)

    reportPromise

  getKeys().then(report).then($ ->
  $item.append """
    <div style="background-color:#eee; padding:8px;">
      <center>
        #{expand item.text}
        <table style="background-color:#f8f8f8; margin:8px; padding:8px; min-width:70%">
          #{$.join('')}
        </table>
        <button>sign</button>
      </center>
    </div>
  """)

bind = ($item, item) ->

  update = ->
    wiki.pageHandler.put $item.parents('.page:first'),
      type: 'edit',
      id: item.id,
      item: item

  $item.dblclick -> wiki.textEditor $item, item

  $item.find('button').click ->
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
    fetch('/plugin/signature/' + timestamp + rev + algo + sum)
      .then((res) -> 
        item.signatures ||= {}
        item.signatures[location.host] ||= {}
        return res.json()
      ).then((json) ->
        console.log 'json', json
        signature = json.signature
        item.signatures[location.host][sum] = {date, timestamp, rev, algo, sum, signature}
        $item.empty()
        emit $item, item
        bind $item, item
        update()
      ).catch((err) ->
        console.error('failure to sign message')
      )


window.plugins.signature = {emit, bind} if window?
module.exports = {expand} if module?

