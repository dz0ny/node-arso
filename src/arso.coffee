request = require 'request'
moment = require 'moment'
_ = require 'underscore'

oddaljenost = (lat1, lon1, lat2, lon2) ->
  ## http://mathworld.wolfram.com/SphericalTrigonometry.html
  R = 6371; #v KM
  return Math.acos(Math.sin(lat1)*Math.sin(lat2) + 
                    Math.cos(lat1)*Math.cos(lat2) *
                    Math.cos(lon2-lon1)) * R

module.exports.location_from_name = (name, cb) ->
  request.get "http://maps.googleapis.com/maps/api/geocode/json?address=#{encodeURI(name)},%20slovenija&sensor=false", (err, b, res) ->
    if err
      new Error err
    else
      res = JSON.parse(res)
      krajg = _.first(_.first(res.results).address_components).short_name
      loc = _.first(res.results).geometry.location
      cb krajg, loc

opendata = (loc, cb)->
  ###
    Vremenski radar na Lisci pri Sevnici sproti meri padavine nad Slovenijo in njeno bližnjo okolico.
    Slika prikazuje razporeditev in jakost padavin, izmerjenih vsakih 10 minut.
    Čas meritve je podan v univerzalnem koordiniranem času UTC; ustrezni uradni čas v Sloveniji je za
    eno uro (pozimi) oziroma za dve uri (poleti) večji. Jakost padavin je predstavljena s štirimi razredi:
    šibka (LOW), zmerna (MED), močna (HGH) in ekstremna (EXT) z možno točo.

    Barve označujejo verjetnost, da se ob prikazanem času na obarvanih območjih pojavlja toča 
    (zelena - ZELO MAJHNA, rumena - ZAZNAVNA; oranžna - MED/medium SREDNJA; rdeča - HGH/high VELIKA)

  ###
  request.get "http://opendata.si/vreme/report/?lat=#{loc.lat.toFixed(4)}&lon=#{loc.lng.toFixed(4)}", (err, b, data) ->
    if err
      new Error err
    else
      data = JSON.parse(data)
      cb data.radar.rain_level, data.hailprob.hail_level, data.forecast.data

module.exports.opendata_radar = (loc, cb)->
  opendata loc, (dez, toca, _napoved_data)->
    
    dezm = switch dez
      when 25 then "Šibke padavine"
      when 50 then "Zmerne padavine"
      when 75 then "Močne padavine"
      when 100 then "Ekstremne padavine"
      else "Stabilno"

    tocam = switch toca
      when 33 then "zaznavno"
      when 66 then "srednjo"
      when 100 then "veliko"
      else "zelo majhno"

    msg_toca_dez = "#{dezm} z #{tocam} verjetnostjo toče!"

    cb
      dezm: dezm
      tocam: tocam
      dez: dez
      toca: toca
      msg: msg_toca_dez

module.exports.opendata_napoved = (loc, cb)->
  opendata loc, (_dez, _toca, napoved_data)->
    oblacnost = 0
    deznost = 0
    stej = 0
    cez_dvanajst_ur = moment().add('h', 12)
    sedaj = moment()
    for f in napoved_data
      """
        BIG IF, ni ravno šloganje sam vseeeno :)
      """
      if moment(f.forecast_time).isAfter(sedaj) and moment(f.forecast_time).isBefore(cez_dvanajst_ur)
        oblacnost += f.clouds
        deznost += f.rain
        stej++
    if (deznost/stej)>5 and (oblacnost/stej)>5
      napoved = "V naslednjih 12 urah je možnost neviht"
    else if (oblacnost/stej)>0
      napoved = "V naslednjih 12 urah je predvidena oblačnost"
    else if (deznost/stej)>0
      napoved = "V naslednjih 12 urah so možne padavine"
    else
      napoved = "V naslednjih 12 urah se obeta stabilno vreme :)"
      
    cb
      napovedm: napoved
      napoved: napoved_data

module.exports.arso = (loc, cb) ->
  yql = (yqlq, cbl) ->
    uri = "http://query.yahooapis.com/v1/public/yql?format=json&q=" + encodeURIComponent(yqlq)
    request
      uri: uri
    , (error, response, body) ->
      body = JSON.parse(body)
      cbl body.query.results

  yql 'select metData.domain_altitude, metData.t, metData.tsValid_issued, metData.domain_longTitle, metData.domain_lat, metData.domain_lon from xml where url in (select title from atom where url="http://spreadsheets.google.com/feeds/list/0AvY_vCMQloRXdE5HajQxUGF5ZEZYUjhKNG9EeVl2bFE/od6/public/basic")',
    (lokacije)->
      lokacije = lokacije.data
      lokacije.sort (a, b)->
        a = oddaljenost a.metData.domain_lat, a.metData.domain_lon, loc.lat, loc.lng
        b = oddaljenost b.metData.domain_lat, b.metData.domain_lon, loc.lat, loc.lng
        return a - b;
      cb _.first(lokacije)         
