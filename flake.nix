{
    inputs = { } ;
    outputs =
        { self } :
            {
                lib =
                    { input ? x : x , output ? x : x } :
                        let
                            implementation =
                                { pkgs , ... } @module :
                                    let
                                        inputed = input module ;
                                        in
                                            with inputed ;
                                                {
                                                    config.systemd =
                                                        {
                                                            services =
                                                                let
                                                                    generator =
                                                                        index :
                                                                            let
                                                                                polling = builtins.elemAt config.promoter.polling index ;
                                                                                in
                                                                                    {
                                                                                        name = "promoter-poll-${ builtins.toString index }" ;
                                                                                        value =
                                                                                            {
                                                                                                after = [ "network-online.target" ] ;
                                                                                                serviceConfig =
                                                                                                    {
                                                                                                        Type = "oneshot" ;
                                                                                                        ExecStart =
                                                                                                            let
                                                                                                                application =
                                                                                                                    pkgs.writeShellApplication
                                                                                                                        {
                                                                                                                            name = "fetch" ;
                                                                                                                            runtimeInputs =
                                                                                                                                [
                                                                                                                                    pkgs.flock
                                                                                                                                    pkgs.jq
                                                                                                                                    pkgs.yq-go
                                                                                                                                    (
                                                                                                                                        pkgs.writeShellApplication
                                                                                                                                            {
                                                                                                                                                name = "poll" ;
                                                                                                                                                runtimeInputs =
                                                                                                                                                    [
                                                                                                                                                        (
                                                                                                                                                            pkgs.writeShellApplication
                                                                                                                                                                {
                                                                                                                                                                    name = "branch" ;
                                                                                                                                                                    runtimeInputs =
                                                                                                                                                                        [
                                                                                                                                                                            pkgs.coreutils
                                                                                                                                                                            pkgs.git
                                                                                                                                                                            pkgs.jq
                                                                                                                                                                            pkgs.yq-go
                                                                                                                                                                            (
                                                                                                                                                                                pkgs.writeShellApplication
                                                                                                                                                                                    {
                                                                                                                                                                                        name = "check" ;
                                                                                                                                                                                        runtimeInputs = [ pkgs.coreutils pkgs.jq pkgs.nix pkgs.yq-go ] ;
                                                                                                                                                                                        text =
                                                                                                                                                                                            ''
                                                                                                                                                                                                BEFORE="$( date +%s )"
                                                                                                                                                                                                : "${ "$" }{CHECK:?CHECK must be exported by the calling script}"
                                                                                                                                                                                                LOG="$( mktemp --suffix ".yaml" ${ config.promoter.directory }/temporary/XXXXXXXX )"
                                                                                                                                                                                                jq --null-input --argjson BEFORE "$BEFORE" '{ "before" : $BEFORE }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                                                DERIVATION="$( nix eval --raw ".#lib.checks.$CHECK.drvPath" )"
                                                                                                                                                                                                if nix build "$DERIVATION" --no-link --show-trace 2>&1 | jq --raw-input '{ "build" : . }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                                                then
                                                                                                                                                                                                    STATUS=true
                                                                                                                                                                                                else
                                                                                                                                                                                                    STATUS=false
                                                                                                                                                                                                fi
                                                                                                                                                                                                touch "${ config.promoter.directory }/timestamp"
                                                                                                                                                                                                export CHECK
                                                                                                                                                                                                AFTER="$( date +%s )"
                                                                                                                                                                                                ELAPSED=$(( AFTER - BEFORE ))
                                                                                                                                                                                                jq --null-input --argjson AFTER "$AFTER" --argjson ELAPSED "$ELAPSED" --argjson STATUS "$STATUS" '{ "after" : $AFTER , "elapsed" : $ELAPSED , "status" : $STATUS }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                                                yq eval --prettyPrint '{ strenv(CHECK) : . }' "$LOG"
                                                                                                                                                                                                rm "$LOG"
                                                                                                                                                                                                if [[ "$STATUS" == "false" ]]
                                                                                                                                                                                                then
                                                                                                                                                                                                    exit 1
                                                                                                                                                                                                fi
                                                                                                                                                                                            '' ;
                                                                                                                                                                                    }
                                                                                                                                                                            )
                                                                                                                                                                        ] ;
                                                                                                                                                                    text =
                                                                                                                                                                        ''
                                                                                                                                                                            BEFORE="$( date +%s )"
                                                                                                                                                                            LOG="$( mktemp --suffix ".yaml" ${ config.promoter.directory }/temporary/XXXXXXXX )"
                                                                                                                                                                            : "${ "$" }{BRANCH:?BRANCH must be exported by the calling script}"
                                                                                                                                                                            STATUS=true
                                                                                                                                                                            jq --null-input --argjson BEFORE "$BEFORE" '{ "before" : $BEFORE }' | yq eval --prettyPrint >> "$LOG"
                                                                                                                                                                            if ! git fetch origin "+${ polling.branch.target }:refs/remotes/origin/${ polling.branch.target }" 2>&1 | jq --raw-input '{ "fetch" : . }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                            then
                                                                                                                                                                                STATUS=false
                                                                                                                                                                            fi
                                                                                                                                                                            if ! git switch --detach "refs/remotes/origin/${BRANCH}" 2>&1 | jq --raw-input '{ "switch" : . }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                            then
                                                                                                                                                                                STATUS=false
                                                                                                                                                                            fi
                                                                                                                                                                            if [[ "$STATUS" == "true" ]]
                                                                                                                                                                            then
                                                                                                                                                                                if ! git rebase "origin/${ polling.branch.target }" 2>&1 | jq --raw-input '{ "rebase" : . }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                                then
                                                                                                                                                                                    STATUS=false
                                                                                                                                                                                fi
                                                                                                                                                                                jq --null-input '{ "checks" : { } }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                                while IFS= read -r CHECK
                                                                                                                                                                                do
                                                                                                                                                                                    export CHECK
                                                                                                                                                                                    if ! check | yq eval --prettyPrint '[.]' >> "$LOG"
                                                                                                                                                                                    then
                                                                                                                                                                                        STATUS=false
                                                                                                                                                                                    fi
                                                                                                                                                                                done < <( nix eval --json .#lib.checks | jq -r 'keys[]' )
                                                                                                                                                                                if ! nix flake check --show-trace --flake ./flake.nix 2>&1 | jq --raw-input '{ "check" : . }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                                then
                                                                                                                                                                                    STATUS=false
                                                                                                                                                                                fi
                                                                                                                                                                                touch "${ config.promoter.directory }/timestamp"
                                                                                                                                                                                if [[ "$STATUS" == "true" ]]
                                                                                                                                                                                then
                                                                                                                                                                                    if git push origin HEAD:refs/heads/${ polling.branch.target } 2>&1 | jq --raw-input '{ "push" : . }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                                    then
                                                                                                                                                                                        git push origin "HEAD:refs/heads/${ polling.branch.success }$BRANCH" > /dev/null 2>&1
                                                                                                                                                                                    else
                                                                                                                                                                                        STATUS=false
                                                                                                                                                                                        git push origin "HEAD:refs/heads/${ polling.branch.failure }$BRANCH" > /dev/null 2>&1
                                                                                                                                                                                    fi
                                                                                                                                                                                fi
                                                                                                                                                                                git push origin "$BRANCH" --delete > /dev/null 2>&1
                                                                                                                                                                            fi
                                                                                                                                                                            AFTER="$( date +%s )"
                                                                                                                                                                            ELAPSED=$(( AFTER - BEFORE ))
                                                                                                                                                                            jq --null-input --argjson AFTER "$AFTER" --argjson ELAPSED "$ELAPSED" --argjson STATUS "$STATUS" '{ "after" : $AFTER , "elapsed" : $ELAPSED , "status" : $STATUS }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                            yq eval --prettyPrint "$LOG"
                                                                                                                                                                            rm "$LOG"
                                                                                                                                                                        '' ;
                                                                                                                                                                }
                                                                                                                                                        )
                                                                                                                                                    ] ;
                                                                                                                                                text =
                                                                                                                                                    ''
                                                                                                                                                        mkdir --parents ${ config.promoter.directory }/temporary
                                                                                                                                                        LOG="$( mktemp --suffix ".yaml" ${ config.promoter.directory }/temporary/XXXXXXXX )"
                                                                                                                                                        BEFORE="$( date +%s )"
                                                                                                                                                        jq --null-input --argjson BEFORE "$BEFORE" '{ "before" : $BEFORE }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                        mkdir --parents ${ config.promoter.directory }/polling/${ builtins.toString index }
                                                                                                                                                        cd "${ config.promoter.directory }/polling/${ builtins.toString index }"
                                                                                                                                                        if [[ ! -d .git ]]
                                                                                                                                                        then
                                                                                                                                                            git init 2>&1 | jq --raw-input '{ "git-init" : . }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                        fi
                                                                                                                                                        git config core.sshCommand "${ polling.committer.ssh-command }"
                                                                                                                                                        git config user.email "${ polling.committer.email }"
                                                                                                                                                        git config user.name "${ polling.committer.name }"
                                                                                                                                                        git config remote.origin.prune true
                                                                                                                                                        if ! git remote get-url origin
                                                                                                                                                        then
                                                                                                                                                            git remote add origin "${ polling.url }"
                                                                                                                                                        else
                                                                                                                                                            git remote set-url origin "${ polling.url }"
                                                                                                                                                        fi
                                                                                                                                                        if git fetch origin "+refs/heads/${ polling.branch.preparation }*:refs/remotes/origin/${ polling.branch.preparation }*" 2>&1 | jq --raw-input '{ "git-fetch" : . }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                        then
                                                                                                                                                            jq --null-input '{ "branches" : { } }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                            while IFS= read -r BRANCH
                                                                                                                                                            do
                                                                                                                                                                export BRANCH
                                                                                                                                                                branch "$BRANCH" | yq eval --prettyPrint '{ strenv('BRANCH') : . }' >> "$LOG"
                                                                                                                                                            done < <( git for-each-ref --format='%(refname:strip=3)' refs/remotes/origin/${ polling.branch.preparation } )
                                                                                                                                                        fi
                                                                                                                                                        AFTER="$( date +%s )"
                                                                                                                                                        ELAPSED=$(( AFTER - BEFORE ))
                                                                                                                                                        jq --null-input --argjson AFTER "$AFTER" --argjson BEFORE "$BEFORE" '{ "after" : $AFTER , "elapsed" : $ELAPSED }' >> "$LOG"
                                                                                                                                                        yq eval --prettyPrint '[.]' "$LOG"
                                                                                                                                                        rm "$LOG"
                                                                                                                                                    '' ;
                                                                                                                                            }
                                                                                                                                    )
                                                                                                                                ] ;
                                                                                                                        text =
                                                                                                                            ''
                                                                                                                                exec 132> ${ config.promoter.directory }/lock
                                                                                                                                flock -x 132
                                                                                                                                mkdir --parents ${ config.promoter.directory }/temporary
                                                                                                                                LOG="$( mktemp --suffix ".yaml" ${ config.promoter.directory }/temporary/XXXXXXXX )"
                                                                                                                                BEFORE="$( date +%s )"
                                                                                                                                poll | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                AFTER="$( date +%s )"
                                                                                                                                ELAPSED=$(( AFTER - BEFORE ))
                                                                                                                                jq --null-input --argjson AFTER "$AFTER" --argjson ELAPSED "$ELAPSED" '{ "after" : $AFTER , "elapsed" : $ELAPSED }' >> "$LOG"
                                                                                                                                yq eval --prettyPrint '.' "$LOG"
                                                                                                                                rm "$LOG"
                                                                                                                            '' ;
                                                                                                                        } ;
                                                                                                                in "${ application }/bin/fetch" ;
                                                                                                        TimeoutStartSec = "${ builtins.toString polling.timeout }s" ;
                                                                                                    } ;
                                                                                                wants = [ "network-online.target" ] ;
                                                                                            } ;
                                                                                    } ;
                                                                    self-delete =
                                                                        {
                                                                            self-delete =
                                                                                {
                                                                                    after = [ "network-online.target" ] ;
                                                                                    serviceConfig =
                                                                                        {
                                                                                            ExecStart =
                                                                                                let
                                                                                                    application =
                                                                                                        pkgs.writeShellApplication
                                                                                                            {
                                                                                                                name = "self-delete" ;
                                                                                                                runtimeInputs = [ pkgs.awscli pkgs.coreutils pkgs.flock ] ;
                                                                                                                text =
                                                                                                                    ''
                                                                                                                        mkdir --parents "${ config.promoter.directory }"
                                                                                                                        exec 104> "${ config.promoter.directory }/lock"
                                                                                                                        flock -x 104
                                                                                                                        NOW="$( date +%s )"
                                                                                                                        if [[ ! -f ${ config.promoter.directory }/timestamp ]]
                                                                                                                        then
                                                                                                                            touch ${ config.promoter.directory }/timestamp
                                                                                                                        fi
                                                                                                                        LAST_MODIFIED="$( stat --format %Y ${ config.promoter.directory }/timestamp )"
                                                                                                                        AGE=$(( NOW - LAST_MODIFIED ))
                                                                                                                        if [[ "$AGE" -gt ${ builtins.toString config.promoter.idle-timeout-seconds } ]]
                                                                                                                        then
                                                                                                                            INSTANCE_ID="$( cat "${ config.promoter.directory }/instance-id" )"
                                                                                                                            aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"
                                                                                                                            aws ec2 wait instance-terminated  --instance-ids "$INSTANCE_ID"
                                                                                                                        fi
                                                                                                                    '' ;
                                                                                                            } ;
                                                                                                    in "${ application }/bin/self-delete" ;
                                                                                        } ;
                                                                                    wants = [ "network-online.target" ] ;
                                                                                } ;
                                                                        } ;
                                                                    in ( builtins.listToAttrs ( builtins.genList generator ( builtins.length config.promoter.polling ) ) ) // self-delete ;
                                                            timers =
                                                                let
                                                                    generator =
                                                                        index :
                                                                            let
                                                                                polling = builtins.elemAt config.promoter.polling index ;
                                                                                in
                                                                                    {
                                                                                        name = "promoter-poll-${ builtins.toString index }" ;
                                                                                        value =
                                                                                            {
                                                                                                wantedBy = [ "timers.target" ] ;
                                                                                                timerConfig =
                                                                                                    {
                                                                                                        OnBootSec = "${ builtins.toString polling.delay }s" ;
                                                                                                        OnUnitActiveSec = "${ builtins.toString polling.interval }s" ;
                                                                                                    } ;
                                                                                            } ;
                                                                                    } ;
                                                                    self-delete =
                                                                        {
                                                                            self-delete =
                                                                                {
                                                                                    wantedBy = [ "timers.target" ] ;
                                                                                    timerConfig =
                                                                                        {
                                                                                            OnBootSec = "${ builtins.toString config.promoter.idle-timeout-seconds }s" ;
                                                                                            OnUnitActiveSec = "${ builtins.toString config.promoter.idle-timeout-seconds }s" ;
                                                                                        } ;
                                                                                } ;
                                                                        } ;
                                                                    in ( builtins.listToAttrs ( builtins.genList generator ( builtins.length config.promoter.polling ) ) ) // self-delete ;
                                                        } ;
                                                    options.promoter =
                                                        {
                                                            directory = lib.mkOption { default = "/root/working/promoter" ; type = lib.types.str ; } ;
                                                            idle-timeout-seconds = lib.mkOption { default = 60 * 60 ; type = lib.types.int ; } ;
                                                            polling =
                                                                lib.mkOption
                                                                    {
                                                                        default = [ ] ;
                                                                        type =
                                                                            let
                                                                                type =
                                                                                    lib.types.submodule
                                                                                        {
                                                                                            options =
                                                                                                {
                                                                                                    branch =
                                                                                                        {
                                                                                                            failure = lib.mkOption { default = "failure/" ; type = lib.types.str ; } ;
                                                                                                            preparation = lib.mkOption { default = "preparation/" ; type = lib.types.str ; } ;
                                                                                                            success = lib.mkOption { default = "success/" ; type = lib.types.str ; } ;
                                                                                                            target = lib.mkOption { default = "main" ; type = lib.types.str ; } ;
                                                                                                        } ;
                                                                                                    committer =
                                                                                                        {
                                                                                                            ssh-command = lib.mkOption { type = lib.types.path ; } ;
                                                                                                            email = lib.mkOption { type = lib.types.str ; } ;
                                                                                                            name = lib.mkOption { type = lib.types.str ; } ;
                                                                                                        } ;
                                                                                                    delay = lib.mkOption { default = 60 ; type = lib.types.int ; } ;
                                                                                                    interval = lib.mkOption { default = 60 * 60 ; type = lib.types.int ; } ;
                                                                                                    timeout = lib.mkOption { default = 60 ; type = lib.types.int ; } ;
                                                                                                    url = lib.mkOption { type = lib.types.str ; } ;
                                                                                                } ;
                                                                                        } ;
                                                                                in lib.types.listOf type ;
                                                                    } ;
                                                        } ;
                                                } ;
                            in
                                {
                                    checks = [ ] ;
                                    implementation = output implementation ;
                                } ;
            } ;
}