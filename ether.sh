#!/bin/bash


# set variables
TERM_WIDTH="$(tput cols)"
COLUMNS="$(printf '%*s\n' "${TERM_WIDTH}" '' | tr ' ' -)"


# set exchange data as functions
function exch_bity() {
  EXCHNAME+=" Bity"
  CURR+=" CHF"
  SLLEXCH+=" https://bity.com/api/v1/rate_we_buy/ETHCHF/"
  SLLJSON+=" rate"
  BUYEXCH+=" https://bity.com/api/v1/rate_we_sell/ETHCHF/"
  BUYJSON+=" rate"
}
function exch_etherscan() {
  EXCHNAME+=" Etherscan"
  CURR+=" USD"
  SLLEXCH+=" https://api.etherscan.io/api?module=stats&action=ethprice"
  SLLJSON+=" ethusd"
  BUYEXCH+=" -"
  BUYJSON+=" -"
}
function exch_lykke() {
  EXCHNAME+=" Lykke"
  CURR+=" CHF"
  SLLEXCH+=" https://lykke-public-api.azurewebsites.net/api/Market/ETHCHF"
  SLLJSON+=" bid"
  BUYEXCH+=" https://lykke-public-api.azurewebsites.net/api/Market/ETHCHF"
  BUYJSON+=" ask"
}

# set functions
function awk_incrun() {
  awk -v var="${INCRUN}" '{print $var}'
}
function help_addr() {
  echo -e "\nA minimum of one Ether wallet address is equired:\n" >&2
  echo -e " -a 0xADDRESS : get the balance of an Ether wallet\n" >&2
}
function help_examples() {
  echo -e "\nExamples:\n" >&2
  echo -e " $(basename ${0}) -a 0xb794F5eA0ba39494cE839613fffBA74279579268 # <-- Single Ether wallet\n" >&2
  echo -e " $(basename ${0}) -a 0xb794F5eA0ba39494cE839613fffBA74279579268 -a 0xE853c56864A2ebe4576a807D26Fdc4A0adA51919 # <-- Multiple Ether wallets\n" >&2
  echo -e " $(basename ${0}) -a 0xb794F5eA0ba39494cE839613fffBA74279579268 -e -b -l -d -v # <-- More information for single Ether wallet from multiple exchanges\n" >&2

}
function help_exch() {
  echo -e "\nOptionally, multiple exchange can be chosen:\n"
  echo -e " -e : Etherscan (etherscan.io)" >&2
  echo -e "      This is the default if no exchange is chosen\n" >&2
  echo -e " -b : Bity (bity.com)\n" >&2
  echo -e " -l : Lykke (lykke.com)\n" >&2
}
function help_intro() {
  echo -e "\n$(basename ${0}) is a script to convert ETH in an Ether wallet into fiat currency according to the chosen exchange\n" >&2
}
function help_optional() {
  echo -e "\nFurther options:\n" >&2
  echo -e " -d : Show date when run\n" >&2
  echo -e " -v : Show exchange rate as well\n" >&2
}
function help_help() {
  echo -e "\nRun \"$(basename ${0}) -h\" to see all available options including available exchanges.\n" >&2
}
function value_format() {
  rev | sed "s/.\{3\}/&'/g" | rev | sed "s/^'//"
}
function zero_trail() {
  sed -e 's/[0]*$//g' -e 's/\.$//'
}


# set switches
while getopts ":a:bedhlv" opt; do
  case ${opt} in
    a)
      ETHER+=" $(echo ${OPTARG})"
      ;;
    d)
      DATE="$(date +%F\ %T)"
      ;;
    b)
      exch_bity
      ;;
    e)
      exch_etherscan
      ;;
    h)
      help_intro
      help_addr
      help_exch
      help_optional
      help_examples
      exit 0
      ;;
    l)
      exch_lykke
      ;;
    v)
      VERBOSE="1"
      ;;
    \?)
      echo -e "\nInvalid option: \"-${OPTARG}\"\n" >&2
      echo -e "Run \"$(basename ${0}) -h\" for help.\n" >&2
      exit 1
      ;;
  esac
done


# remove whitespaces and remove double entries for wallets addresses
ETHER="$(echo "${ETHER}" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//' -e 's/\b\([a-z]\+\)[ ,\n]\1/\1/' | tr ' ' '\n' | sort -fu)"


# check if given wallet address
if [[ -z "${ETHER}" ]]; then
  help_intro
  help_addr
  help_help
  exit 1
fi


# start output
echo


# if given, output current date
if ! [[ -z "${DATE}" ]]; then
  echo -e "${COLUMNS}\nDATE : ${DATE}"
fi


# start incremental run through all wallet addresses
for ETHERWALLET in ${ETHER}; do

  # check if wallet address is valid
  if ! echo "${ETHERWALLET}" | grep -q '^0x[[:alnum:]]\{40\}$'; then
    echo -e "${COLUMNS}\"${ETHERWALLET}\" is not a valid Ether address!"

  else
    # choose default exchange if no exchange was specified
    if [[ -z "${SLLEXCH}" ]]; then
      exch_etherscan
    fi


    # get ETH balance in WEI
    ETHWEI="$(curl -s "https://api.etherscan.io/api?module=account&action=balance&address=${ETHERWALLET}&tag=latest" | python -mjson.tool 2> /dev/null | grep "\"result\": " | awk -F\: '{print $2}' | sed 's/[^0-9]//g')"

    # check that balance is not 0
    NORUN="0"
    if [[ "${ETHWEI}" -eq "0" ]]; then
      echo -e "${COLUMNS}Wallet \"${ETHERWALLET}\" has no ETH!"
      NORUN="1"
    fi


    # if balance is ok, run through exchanges
    if [[ "${NORUN}" -ne "1" ]] ; then
      # convert WEI balance by 10^18
      ETH="$(echo "scale=20;${ETHWEI} / 10^18" | bc | sed 's/^./0./')"

      # format ETH values for output
      ETHFORM="$(echo ${ETH} | awk -F\. '{print $1}' | value_format)"
      ETHMINI="$(echo ${ETH} | awk -F\. '{print $2}' | zero_trail)"


      # output Ether wallet address and amount
      echo -e "${COLUMNS}\nADDR : ${ETHERWALLET}"
      echo "ETH  : ${ETHFORM}$( if [[ ! -z "${ETHMINI}" ]]; then echo ".${ETHMINI}"; fi)"



      # set variable for incremental runs
      INCRUN="0"

      # run once per given exchange
      for i in ${EXCHNAME}; do

        # increment run
        ((INCRUN++))
        INCCURR="$(echo ${CURR} | awk_incrun)"
        INCSLLEXCH="$(echo ${SLLEXCH} | awk_incrun)"
        INCSLLJSON="$(echo ${SLLJSON} | awk_incrun)"
        INCBUYEXCH="$(echo ${BUYEXCH} | awk_incrun)"
        INCBUYJSON="$(echo ${BUYJSON} | awk_incrun)"

        # print exchange
        echo -e "\nEXCH : ${i}"

        # get fiat buying rate
        SLLFIAT="$(curl -s "${INCSLLEXCH}" | python -mjson.tool | grep "\"${INCSLLJSON}\": " | awk -F\: '{print $2}' | sed 's/[^.0-9]//g' | zero_trail)"

        # calculate converted rate and format it nicely
        DOLLAR="$(echo "scale=0; ${ETH} * ${SLLFIAT} / 1" | bc | value_format)"
        CENT="$(echo "scale=2; ${ETH} * ${SLLFIAT} / 1" | bc | awk -F\. '{print $2}')"
        TOTAL="${DOLLAR}.${CENT}"
        TOTAL="$(echo "${TOTAL}" | sed -e 's/\.0$//' -e 's/\.$//')"


        # create detailed output
        echo "${INCCURR}  : ${TOTAL}"


        # verbose output
        if ! [[ -z "${VERBOSE}" ]]; then
          if echo "${INCBUYEXCH}" | grep -qE "https?://"; then
            BUYFIAT="$(curl -s "${INCBUYEXCH}" | python -mjson.tool | grep "\"${INCBUYJSON}\": " | awk -F\: '{print $2}' | sed 's/[^.0-9]//g' | zero_trail)"
            echo "BUY  : ${BUYFIAT} ${INCCURR}/ETH"
          fi

          echo "SELL : ${SLLFIAT} ${INCCURR}/ETH"
        fi
      done
    fi
  fi
done


# exit script
echo -e "${COLUMNS}\n"
exit $?
