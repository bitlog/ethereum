#!/bin/bash


# variables that need to be set by environment
DIR="${HOME}/data/eth/"


# prepare variables
DATE="$(date +%F_%T)"
FILENAME="eth-exchange-"
FILE="${DIR}${FILENAME}$(date +%F)"


# set switches
while getopts ":fp" opt; do
  case ${opt} in
    f)
      FETCH="1"
      ;;
    p)
      PLOT="1"
      ;;
    \?)
      echo -e "\nInvalid option: \"-${OPTARG}\"\n" >&2
      exit 1
      ;;
  esac
done


# create directory if empty
if [[ ! -d "${DIR}" ]] && [[ ! -L "${DIR}" ]]; then
  mkdir ${DIR} || exit 1
  echo -e "\nCreated \"${DIR}\" to store data within.\n" >&2
fi


# check if given switches
if [[ -z "${FETCH}" ]] && [[ -z "${PLOT}" ]]; then
  echo -e "\nRun \"$(basename ${0})\" either with \"-f\" or \"-p\".\n" >&2
  exit 1
fi


# set exchange names
EXCHNAME="Bity"
EXCHCOLOR="cyan blue"

EXCHNAME="${EXCHNAME} Lykke"
EXCHCOLOR="${EXCHCOLOR} pink red"


# run data fetch
if [[ ! -z "${FETCH}" ]]; then
  # set functions
  function awk_incrun() {
    awk -v var="${INCRUN}" '{print $var}'
  }
  function exchange_format() {
    awk -F\: '{print $2}' | sed -e 's/[^.0-9]//g'
  }


  # set exchange data for Bity
  SLLEXCH="https://bity.com/api/v1/rate_we_buy/ETHCHF/"
  SLLJSON="rate"
  BUYEXCH="https://bity.com/api/v1/rate_we_sell/ETHCHF/"
  BUYJSON="rate"

  # set exchange data for Lykke
  SLLEXCH="${SLLEXCH} https://lykke-public-api.azurewebsites.net/api/Market/ETHCHF"
  SLLJSON="${SLLJSON} bid"
  BUYEXCH="${BUYEXCH} https://lykke-public-api.azurewebsites.net/api/Market/ETHCHF"
  BUYJSON="${BUYJSON} ask"


  # set variable for incremental runs
  INCRUN="0"

  # run once per given exchange
  for i in ${EXCHNAME}; do
    ((INCRUN++))
    INCSLLEXCH="$(echo ${SLLEXCH} | awk_incrun)"
    INCSLLJSON="$(echo ${SLLJSON} | awk_incrun)"
    INCBUYEXCH="$(echo ${BUYEXCH} | awk_incrun)"
    INCBUYJSON="$(echo ${BUYJSON} | awk_incrun)"

    # fetch exchange data
    SLLEXCHDATA="$(curl -s "${INCSLLEXCH}" | python -mjson.tool 2> /dev/null)"
    BUYEXCHDATA="$(curl -s "${INCBUYEXCH}" | python -mjson.tool 2> /dev/null)"


    # check exchange data
    if [[ -z "${SLLEXCHDATA}" ]] || [[ -z "${BUYEXCHDATA}" ]]; then
      exit 1
    fi


    # get prices
    PRICES="${PRICES},$(echo "${BUYEXCHDATA}" | grep "\"${INCBUYJSON}\": " | exchange_format),$(echo "${SLLEXCHDATA}" | grep "\"${INCSLLJSON}\": " | exchange_format)"
  done


  # create file if empty
  if [[ ! -s "${FILE}.csv" ]]; then
    touch ${FILE}.csv || exit 1
  fi

  # output data
  echo "${DATE}${PRICES}" >> ${FILE}.csv
fi


# run graph creation
if [[ ! -z "${PLOT}" ]]; then
  # set functions
  function exchcolor() {
    awk -v color="${INCCOLOR}" '{print $color}'
  }
  # set variable for incremental runs
  INCRUN="1"
  INCCOLOR="0"

  # set plot line
  for i in ${EXCHNAME}; do
    # Run Buy
    ((INCRUN++))
    ((INCCOLOR++))
    PLOTDATA="${PLOTDATA} '${FILE}.csv' using 1:${INCRUN} lt 1 lc rgb '$(echo "${EXCHCOLOR}" | exchcolor)' title 'Buy - ${i}' with lines,"

    # Run Sell
    ((INCRUN++))
    ((INCCOLOR++))
    PLOTDATA="${PLOTDATA} '${FILE}.csv' using 1:${INCRUN} lt 1 lc rgb '$(echo "${EXCHCOLOR}" | exchcolor)' title 'Sell - ${i}' with lines,"
  done

  # clean up plot line
  PLOTDATA="$(echo "${PLOTDATA}" | sed 's/,$//')"


  # run through all CSV files
  for i in $(ls ${DIR}${FILENAME}*.csv); do
    PLOTTITLE="$(echo "${i}" | tr '/' '\n' | grep ".csv$" | sed -e "s/^${FILENAME}//" -e 's/.csv$//')"

    # set plot configuration options
    PLOTCONFIG="reset
    set autoscale
    set encoding utf8
    set key outside top left

    set title 'ETH prices - ${PLOTTITLE}'

    set datafile separator ','
    set timefmt '%Y-%m-%d_%H:%M:%S'
    set format x '%H:%M'
    set xdata time

    set grid ytics
    set grid xtics"

    # plot full size image
    echo -e "${PLOTCONFIG}
    set terminal png medium size 1920,1080 # Full HD resolution
    set output '${FILE}.png'
    plot ${PLOTDATA}" | gnuplot

    # plot thumbnail image
    echo -e "${PLOTCONFIG}
    set terminal png tiny size 640,360 # Half HD resolution
    set output '${FILE}.thumbnail.png'
    plot ${PLOTDATA}" | gnuplot
  done
fi


# end
exit $?
