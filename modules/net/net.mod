#!/usr/bin/env bash

###################################################################
#  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  #
###################################################################

###################################################################
# SPECIFIC MODULE HEADER
# This module performs elementary network analyses.
###################################################################
mod_name_short=net
mod_name='NETWORK ANALYSIS MODULE'
mod_head=${XCPEDIR}/core/CONSOLE_MODULE_RC

###################################################################
# GENERAL MODULE HEADER
###################################################################
source ${XCPEDIR}/core/constants
source ${XCPEDIR}/core/functions/library.sh
source ${XCPEDIR}/core/parseArgsMod

#################################################################f##
# MODULE COMPLETION AND ANCILLARY FUNCTIONS
###################################################################
update_networks() {
   for g in ${gammas[@]}
      do
      gf=${g//\./-}
      atlas_add   ${a_name}   CommunityRes${g}  ${netbase[${cxt}]}_CommunityRes${gf}_community.1D
   done
}

completion() {
   write_atlas
   
   source ${XCPEDIR}/core/auditComplete
   source ${XCPEDIR}/core/updateQuality
   source ${XCPEDIR}/core/moduleEnd
}

community_detection() {
   echo_cmd "matlab : addpath(genpath('${XCPEDIR}/thirdparty/'))"
   echo_cmd "matlab : addpath(genpath('${XCPEDIR}/utils/'))"
   echo_cmd "matlab : glconsensusCL('${adjacency[${cxt}]}','${com_root[${cxt}]}','gamma',${gamma},'nreps',${net_consensus[${cxt}]}${missing_arg})"
   matlab -nodesktop \
      -nosplash \
      -nojvm \
      -r "addpath(genpath('${XCPEDIR}/thirdparty/')); addpath(genpath('${XCPEDIR}/utils/')); glconsensusCL('${adjacency}','${com_root[${cxt}]}','gamma',${gamma},'nreps',${net_consensus[${cxt}]}${missing_arg}); exit"\
      2>/dev/null 1>&2
   echo_cmd "matlab : exit"
}





###################################################################
# OUTPUTS
###################################################################
gammas=( ${net_gamma[${cxt}]//,/ } )

<< DICTIONARY

gammas
   Not strictly an output. An array specifying all resolution
   parameters for the community detection procedure.

DICTIONARY










###################################################################
# Retrieve all the networks for which analysis should be run, and
# prime the analysis.
###################################################################
subroutine                    @0.1
load_atlas                    ${atlas[${subjidx}]}





###################################################################
# Iterate through all networks.
#
# In brief, the network analysis process consists of the
# following steps:
#        . . .
#  ~ TO ~ BE ~ EXPANDED ~
#        . . .
#  X. Perform consensus-community detection on the adjacency
#     matrix to partition it into subgraphs.
###################################################################
for net in ${atlas_names[@]}
   do
   atlas_parse ${net}
   [[ -z ${a_matrix} ]] && continue
   routine                    @1    Network analysis: ${a_name}
   configure   netdir               ${outdir}/${a_name}
   configure   netbase              ${netdir[${cxt}]}/${prefix}_${a_name}
   mkdir -p    ${netdir[${cxt}]}





   for adjacency in ${a_matrix[@]}
      do
      #############################################################
      # Compute the community partition.
      #############################################################
      case ${net_com[${cxt}]} in
      genlouvain)
         subroutine           @1.1.1   Detecting community structure
         for gamma in ${gammas[@]}
            do
            gamma_filename=${gamma//\./-}
            configure   com_root       ${netbase[${cxt}]}_CommunityRes${gamma_filename}
            configure   community      ${com_root[${cxt}]}_community.1D
            if [[ ! -s  ${community[${cxt}]} ]] \
            || rerun
               then
               subroutine     @1.1.2
               community_detection
            fi
            if [[ ! -s ${com_root[${cxt}]}_wbOverall.csv ]] \
            || rerun
               then
               exec_xcp withinBetween.R \
                  -m ${adjacency} \
                  -c ${community[${cxt}]} \
                  -o ${com_root[${cxt}]}
            fi
         done
         ;;
      none)
         subroutine           @1.1.3
         ;;
      esac
      #############################################################
      # Include a priori partitions if requested.
      #############################################################
      subroutine              @1.2  Computing community statistics
      for i in $(seq ${#a_community_names[@]})
         do
         subroutine           @1.2.1
         (( i-- ))
         partition_name=${a_community_names[i]}
         if [[ ! -s ${netbase[${cxt}]}_${partition_name}_wbOverall.csv ]] \
         || rerun
            then
            subroutine        @1.2.2
            exec_sys rm -f ${netbase[${cxt}]}_${partition_name}Quality.txt
            exec_xcp quality.R \
               -m ${adjacency} \
               -c ${a_community[i]} \
               >> ${netbase[${cxt}]}_${partition_name}Quality.txt
            exec_xcp withinBetween.R \
               -m ${adjacency} \
               -c ${a_community} \
               -o ${netbase[${cxt}]}_${partition_name}
         fi
      done
   done
   update_networks
   routine_end
done

completion
