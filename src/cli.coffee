#!/usr/bin/env coffee
cli = require('commander')
fs = require('fs')
vreme = require("#{__dirname}/lib/arso")

app =  JSON.parse fs.readFileSync "#{__dirname}/../package.json", 'utf-8'

cli
  .version(app.version)
cli
  .command("vreme <kraj> [json_kljuc]")
  .description("Vreme za izbrani <kraj>, [json_kluc] v json dokumentu")
  .action (kraj, json) ->
    vreme.location_from_name kraj, (kraj, loc)->
      vreme.arso loc, (arso)->
        if json?
          console.log arso.metData[json]
        else
          console.log arso.metData
cli
  .command("razmere <kraj> [json_kljuc]")
  .description("Radarske za izbrani <kraj>, [json_kluc] v json dokumentu")
  .action (kraj, json) ->
    vreme.location_from_name kraj, (kraj, loc)->
      vreme.opendata_radar loc, (opendata)->
        if json?
          console.log opendata[json]
        else
          console.log opendata
cli
  .command("napoved <kraj> [json_kljuc]")
  .description("Napoved za naslednjih 12 ur za izbrani <kraj>, [json_kluc] v json dokumentu")
  .action (kraj, json) ->
    vreme.location_from_name kraj, (kraj, loc)->
      vreme.opendata_napoved loc, (opendata)->
        if json?
          console.log opendata[json]
        else
          console.log opendata

cli.parse process.argv