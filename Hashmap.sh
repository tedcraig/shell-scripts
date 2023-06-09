#! /usr/bin/env bash

# =============================================================================
#
#   name:   Hashmap.sh
#   auth:   ted craig
#
#   desc:   Provides hacky, hashmap/dictionary-like data "object" for bash v3
#           (or other bash versions that do not support associative arrays).
#
#   note:   Developed and tested on MacOs Ventura using bash v3.2.57(1)-release
#
# =============================================================================


create_hashmap() {
    [[ $# -lt 1 ]] && {
        echo "$FUNCNAME requires at least one argument."
        exit 1
    }
    
    ## setup infrastructure for this hashmap instance
    local this=$1
    local class="Hashmap"
    
    eval "${this}_KEYS=()"
    eval "${this}_VALUES=()"
    eval "${this}_AVAILABLE_INDEXES=(0)"
    
    ## create "alias" function for each class function using
    ## naming convention:  instanceName::methodName
    for method in $(compgen -A function "${class}_")
    do
        # echo "$method in loop";
        local prep="${method/#$class\_/$this::}() { ${method} ${this} "'$@'"; }"
        # echo $prep
        eval $prep
    done
    
    ## handle any key/value pairs passed to us
    shift   ## remove instance name arg
    [[ $# -lt 1 ]] && {
        ## no key/value pairs, so break out of this function
        return
    }
    Hashmap_add "${this}" "$@"
}

## add key/value pairs to hashmap
Hashmap_add() {
    # echo "${FUNCNAME[0]} invoked"
    # echo "args: $@"
    local this=$1
    ## handle key/value pairs passed to us
    shift   ## remove instance name arg
    [[ $# -lt 1 ]] && {
        ## no key/value pairs, so break out of this function
        return
    }
    for kv_pair in $@; do
        local KEY=${kv_pair%=*}
        local VAL=${kv_pair#*=}
        # eval 'local INDEX=${#'"$this"'_KEYS[@]}'
        eval 'local INDEX=${'"${this}"'_AVAILABLE_INDEXES[0]}'
        eval 'local INDEXES_LENGTH=${#'"${this}"'_AVAILABLE_INDEXES[@]}'

        ## declare temp variable to be used as prep for eval statements
        local prep=

        if [[ "${INDEXES_LENGTH}" == "1" ]]; then
            ## we must be pushing on to the end of the array
            ## so update the value to be the new index for the next array element
            # echo "available indexes: ${INDEXES_LENGTH}"
            # echo "1 available index.  Overwrite"
            prep="${this}"'_AVAILABLE_INDEXES[0]='"$(( INDEX + 1 ))"
            # echo $prep
            eval $prep
        else
            ## remove the 0-th index of AVAILABLE_INDEXES since it is now in use
            # echo "available indexes: ${INDEXES_LENGTH}"
            prep="${this}"'_AVAILABLE_INDEXES=(${'"${this}"'_AVAILABLE_INDEXES[@]:1})'
            # echo $prep
            eval $prep
        fi

        eval 'INDEXES_LENGTH=${#'"${this}"'_AVAILABLE_INDEXES[@]}'
        # echo "updated avail indexes: ${INDEXES_LENGTH}"
        # echo "KEY: $KEY | VAL: $VAL | INDEX: $INDEX"
        
        prep="${this}"'_KEYS['"${INDEX}"']='"${KEY}"
        # echo "$prep"
        eval $prep
        
        prep="${this}"'_VALUES['"${INDEX}"']='"${VAL}"
        # echo "$prep"
        eval $prep
        
        prep="${this}"'_KEY_'"${KEY}"'='"${INDEX}"
        # echo "$prep"
        eval $prep
    done
}


Hashmap_get() {
    # echo "${FUNCNAME[0]} invoked"
    # echo "args: $@"
    local this=$1
    local KEY=$2
    local prep='local var="${'"${this}"'_KEY_'"${KEY}"'}"'
    # echo $prep
    eval "$prep"
    # echo "var: ${var}"
    [[ -z  ${var} ]] && {
        echo "${FUNCNAME[0]}: Unable to get $this hashmap value. Unknown key: $KEY"
        exit 1
    }
    local prep='local INDEX=${'"${this}_KEY_${KEY}"'}'
    # echo $prep
    eval $prep
    # echo "INDEX: ${INDEX}"
    prep='local VAL=${'"${this}"'_VALUES['"${INDEX}"']}'
    # echo $prep
    eval $prep
    # echo "$KEY: $VAL"
    echo "${VAL}"
}

Hashmap_delete() {
    # echo "${FUNCNAME[0]} invoked"
    # echo "args: $@"
    local this=$1
    local KEY=$2
    eval 'local KEYS_LENGTH=${#'"${this}"'_KEYS[@]}'
    eval 'local VALS_LENGTH=${#'"${this}"'_VALUES[@]}'
    eval 'local IDXS_LENGTH=${#'"${this}"'_AVAILABLE_INDEXES[@]}'
    local prep='local var="${'"${this}"'_KEY_'"${KEY}"'}"'
    # echo $prep
    eval "$prep"
    # echo "var: ${var}"
    [[ -z  ${var} ]] && {
        echo "${FUNCNAME[0]}: Unable to delete $this hashmap entry. Unknown key: $KEY"
        exit 1
    }
    prep='local INDEX=${'"${this}_KEY_${KEY}"'}'
    echo $prep
    eval $prep
    # echo "INDEX: ${INDEX}"
    if [[ INDEX == 0 ]] && [[ KEYS_LENGTH == 1 ]] && [[ VALS_LENGTH == 1 ]]; then
        ## this is the only element in the AVAILABLE_INDEXES array so just skip this step
        break
    elif (( INDEX == KEYS_LENGTH - 1 )) && (( INDEX == VALS_LENGTH - 1 )); then
        ## this is not the only element in the AVAILABLE_INDEXES array 
        ## so just add it as the last available index
        eval "${this}"'_AVAILABLE_INDEXES=( "${'"${this}"'_AVAILABLE_INDEXES[@]}" "${'"${INDEX}"'}" )'
    else
        ## this is not the last element so insert it before the last element of the AVAILABLE_INDEXES array
        prep="${this}"'_AVAILABLE_INDEXES=( ${'"${this}"'_AVAILABLE_INDEXES[@]:0:'"$((IDXS_LENGTH - 2))"'} '"${INDEX}"' ${'"${this}"'_AVAILABLE_INDEXES[@]:'"$((IDXS_LENGTH - 2))"'} )'
        # echo $prep
        eval $prep
    fi

    ## "remove" key corresponding to this index
    prep="${this}"'_KEYS['"${INDEX}"']=deleted_from_'"${this}"
    # echo "$prep"
    eval $prep
    
    ## "remove" the value corresponding to this key
    prep="${this}"'_VALUES['"${INDEX}"']=deleted_from_'"${this}"
    # echo "$prep"
    eval $prep
    
    ## remove the index pointer
    prep='unset '"${this}"'_KEY_'"${KEY}"
    # echo "$prep"
    eval $prep

    # print some debug info
    eval 'echo "${this}_KEYS: ${'"${this}"'_KEYS[@]}"'
    eval 'echo "${this}_VALUES: ${'"${this}"'_VALUES[@]}"'
    eval 'echo "${this}_AVAILABLE_INDEXES: ${'"${this}"'_AVAILABLE_INDEXES[@]}"'
}


Hashmap_list() {
    this=$1
    local prep=
    echo -n "$this:"
    eval 'local KEYS_LENGTH=${#'"${this}"'_KEYS[@]}'
    for (( INDEX=0; INDEX < KEYS_LENGTH; INDEX++ )); do
        ## skip if this index corresponds to a "deleted" element
        prep='[[ ${'"${this}"'_KEYS['"${INDEX}"']} == deleted_from_'"${this}"' ]]'
        eval $prep && continue
        ## if we get this far, go ahead and add this key/value pair to the listing
        eval 'echo -n " ${'"${this}"'_KEYS['"${INDEX}"']}=${'"${this}"'_VALUES['"${INDEX}"']}"'
    done;
    echo
}



other_func() {
    # echo ${FUNCNAME[0]} invoked
    echo "one two three"
}
