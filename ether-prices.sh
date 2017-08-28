#!/bin/bash


# variables that need to be set by environment
CURR="ETH"
CRCY="eth"
DIR="${HOME}/data/${CRCY}/"


# prepare variables
DATE="$(date '+%F_%T')"
TODAY="$(date '+%F')"
MONTH="$(date '+%Y-%m')"
YEAR="$(date '+%Y')"
FILENAME="${CRCY}-exchange-"
FILE="${DIR}${FILENAME}"


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
  mkdir -p ${DIR} || exit 1
fi

# change to directory
cd ${DIR} || exit 1


# check if given switches
if [[ -z "${FETCH}" ]] && [[ -z "${PLOT}" ]]; then
  echo -e "\nRun \"$(basename ${0})\" either with \"-f\" or \"-p\".\n" >&2
  exit 1
fi


# set exchange names
EXCHNAME="Bity"
EXCHCURR="CHF"

EXCHNAME+=" Lykke"
EXCHCURR+=" CHF"


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
  BUYEXCH="https://bity.com/api/v1/rate_we_sell/ETHCHF/"
  BUYJSON="rate"
  SLLEXCH="https://bity.com/api/v1/rate_we_buy/ETHCHF/"
  SLLJSON="rate"

  # set exchange data for Lykke
  BUYEXCH+=" https://lykke-public-api.azurewebsites.net/api/Market/ETHCHF"
  BUYJSON+=" ask"
  SLLEXCH+=" https://lykke-public-api.azurewebsites.net/api/Market/ETHCHF"
  SLLJSON+=" bid"


  # set variable for incremental runs
  INCRUN="0"
  PRCRUN="1"

  # run once per given exchange
  for i in ${EXCHNAME}; do
    ((INCRUN++))
    INCBUYEXCH="$(echo ${BUYEXCH} | awk_incrun)"
    INCBUYJSON="$(echo ${BUYJSON} | awk_incrun)"
    INCSLLEXCH="$(echo ${SLLEXCH} | awk_incrun)"
    INCSLLJSON="$(echo ${SLLJSON} | awk_incrun)"

    # fetch exchange data
    BUYEXCHDATA="$(curl -s "${INCBUYEXCH}" | python -mjson.tool 2> /dev/null)"
    SLLEXCHDATA="$(curl -s "${INCSLLEXCH}" | python -mjson.tool 2> /dev/null)"


    # set buy price
    ((PRCRUN++))
    if [[ -z "${BUYEXCHDATA}" ]]; then
      BUYPRICE=""
    else
      BUYPRICE="$(echo "${BUYEXCHDATA}" | grep "\"${INCBUYJSON}\": " | exchange_format)"
      if echo "${BUYPRICE}" | grep -qE "^0$|^0\.0*$"; then
        BUYPRICE=""
      fi
    fi

    # set sell price
    ((PRCRUN++))
    if [[ -z "${SLLEXCHDATA}" ]] || echo "${SLLEXCHDATA}" | grep -qE "^0$|^0\.0*$"; then
      SLLPRICE=""
    else
      SLLPRICE="$(echo "${SLLEXCHDATA}" | grep "\"${INCSLLJSON}\": " | exchange_format)"
      if echo "${SLLPRICE}" | grep -qE "^0$|^0\.0*$"; then
        SLLPRICE=""
      fi
    fi

    # set price total
    PRICES+=",${BUYPRICE},${SLLPRICE}"
  done


  # create header string
  INCRUN="0"
  for i in ${EXCHNAME}; do
    ((INCRUN++))
    INCCURR="$(echo "${EXCHCURR}" | awk_incrun )"
    HEADER+=",Buy ${i} (${INCCURR}),Sell ${i} (${INCCURR})"
  done
  HEADER="Date${HEADER}"


  # output into files
  for i in ${TODAY} ${MONTH} ${YEAR} all; do
    if [[ ! -s "${FILE}${i}.csv" ]]; then
      echo "${HEADER}" > ${FILE}${i}.csv || exit 1
    else
      sed -i "1 s/^.*/${HEADER}/" ${FILE}${i}.csv || exit 1
    fi

    echo "${DATE}${PRICES}" >> ${FILE}${i}.csv
  done
fi


# run graph creation
if [[ ! -z "${PLOT}" ]]; then
  # set variables
  START="$(awk 'FNR==2' ${FILE}all.csv | awk -F',' '{print $1}')"
  FINISH="$(tail -1 ${FILE}all.csv | awk -F',' '{print $1}')"

  if [[ "$START" != "${FINISH}" ]]; then
    TIMEZONE="$(date --date "$(echo ${FINISH} | sed 's/_/ /')" '+%A, %_d %B %Y, %T %Z (UTC %:::z)' | sed -e 's/  / /g' -e 's/+0/+/g')"
    DAILY="$(date --date '-1 day' '+%F_%T')"
    WEEKLY="$(date --date '-1 week' '+%F_%T')"
    MONTHLY="$(date --date '-1 month' '+%F_%T')"


    # run through creation ranges
    for i in daily weekly monthly all; do
      # set variable for incremental runs
      INCRUN="1"
      INCSTYLE="1"


      # set plot line
      unset PLOTDATA
      for c in ${EXCHNAME}; do
        # Run Buy
        ((INCRUN++))
        PLOTDATA+=" \"${FILE}all.csv\" using 1:(\$${INCRUN}) with lines ls ${INCSTYLE},"
        ((INCSTYLE++))

        # Run Sell
        ((INCRUN++))
        PLOTDATA+=" \"${FILE}all.csv\" using 1:(\$${INCRUN}) with lines ls ${INCSTYLE},"
        ((INCSTYLE++))
      done

      # clean up plot line
      PLOTDATA="$(echo "${PLOTDATA}" | sed 's/,$//')"


      # set variables for plot
      PLOTTITLE="${i} prices"


      # set date format
      if [[ "${i}" == "all" ]]; then
        DATEFORMAT="set format x '%Y-%m'"
        XRANGE="set xrange ['${START}':'${FINISH}']"
      elif [[ "${i}" == "monthly" ]]; then
        DATEFORMAT="set format x '%m-%d'"
        XRANGE="set xrange ['${MONTHLY}':'${FINISH}']"
      elif [[ "${i}" == "weekly" ]]; then
        DATEFORMAT="set format x '%m-%d'"
        XRANGE="set xrange ['${WEEKLY}':'${FINISH}']"
      else
        DATEFORMAT="set format x '%H:%M'"
        XRANGE="set xrange ['${DAILY}':'${FINISH}']"
      fi


      # plot full size image
      echo -e "reset
      set autoscale
      set encoding utf8
      set key autotitle columnheader outside top left width 1 spacing 1

      set datafile separator ','
      set datafile missing
      set timefmt '%Y-%m-%d_%H:%M:%S'
      set xdata time

      set grid xtics
      set grid ytics

      set y2tics

      ${DATEFORMAT}
      ${XRANGE}

      set terminal pngcairo size 1000,500 enhanced font ',10'

      set style line 1 lt rgb 'cyan'
      set style line 2 lt rgb 'blue'
      set style line 3 lt rgb 'gray'
      set style line 4 lt rgb 'black'
      set style line 5 lt rgb 'pink'
      set style line 6 lt rgb 'red'
      set style line 7 lt rgb 'yellow'
      set style line 8 lt rgb 'green'

      set xlabel 'Copyright © ${YEAR} Sean Rütschi'
      set x2label '${TIMEZONE}'

      set output '${DIR}.${FILENAME}${i}.png'
      set title '${CURR} ${PLOTTITLE}'
      plot ${PLOTDATA}" | gnuplot && mv ${DIR}.${FILENAME}${i}.png ${FILE}${i}.png
    done
  fi
fi


# end
exit $?
