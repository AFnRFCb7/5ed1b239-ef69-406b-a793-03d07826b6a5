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
                                                    options.promoter =
                                                        {
                                                            bin =
                                                                {
                                                                    halt =
                                                                        lib.mkOption
                                                                            {
                                                                                default =
                                                                                    pkgs.writeShellApplication
                                                                                        {
                                                                                            name = "halt" ;
                                                                                            runtimeInputs = [ pkgs.coreutils pkgs.flock ] ;
                                                                                            text =
                                                                                                ''
                                                                                                    mkdir --parents "${ config.promoter.directory }"
                                                                                                    exec 154> "${ config.promoter.directory }/control.lock"
                                                                                                    flock -x 154
                                                                                                    echo HALT > "${ config.promoter.directory }/control.asc"
                                                                                                    if [[ -f "${ config.promoter.directory }/control.pid" ]]
                                                                                                    then
                                                                                                        flock -u 154
                                                                                                        PID="$( cat "${ config.promoter.directory }/control.pid" )"
                                                                                                        tail --follow --pid="$PID" /dev/null
                                                                                                    fi
                                                                                                '' ;
                                                                                        } ;
                                                                                type = lib.types.package ;
                                                                            } ;
                                                                    poll =
                                                                        lib.mkOption
                                                                            {
                                                                                default =
                                                                                    pkgs.writeShellApplication
                                                                                        {
                                                                                            name = "poll" ;
                                                                                            runtimeInputs =
                                                                                                [
                                                                                                    pkgs.coreutils
                                                                                                    (
                                                                                                        pkgs.writeShellApplication
                                                                                                            {
                                                                                                                name = "launch" ;
                                                                                                                runtimeInputs =
                                                                                                                    [
                                                                                                                        (
                                                                                                                            pkgs.writeShellApplication
                                                                                                                                {
                                                                                                                                    name = "iterate" ;
                                                                                                                                    runtimeInputs =
                                                                                                                                        [
                                                                                                                                            pkgs.jq
                                                                                                                                            pkgs.yq-go
                                                                                                                                            (
                                                                                                                                                pkgs.writeShellApplication
                                                                                                                                                    {
                                                                                                                                                        name = "repository" ;
                                                                                                                                                        runtimeInputs =
                                                                                                                                                            [
                                                                                                                                                                pkgs.coreutils
                                                                                                                                                                pkgs.git
                                                                                                                                                                pkgs.jq
                                                                                                                                                                pkgs.yq-go
                                                                                                                                                                (
                                                                                                                                                                    pkgs.writeShellApplication
                                                                                                                                                                        {
                                                                                                                                                                            name = "branch" ;
                                                                                                                                                                            runtimeInputs =
                                                                                                                                                                                [
                                                                                                                                                                                    pkgs.coreutils
                                                                                                                                                                                    pkgs.git
                                                                                                                                                                                    pkgs.jq
                                                                                                                                                                                    pkgs.nix
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
                                                                                                                                                                                    if git fetch origin "+$TARGET:refs/remotes/origin/$TARGET" 2>&1 | jq --raw-input '{ "fetch" : . }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                                    then
                                                                                                                                                                                        BOOTSTRAP=false
                                                                                                                                                                                    else
                                                                                                                                                                                        if git show-ref --verify --quiet "refs/remotes/origin/$TARGET"
                                                                                                                                                                                        then
                                                                                                                                                                                            BOOTSTRAP=false
                                                                                                                                                                                            STATUS=false
                                                                                                                                                                                        else
                                                                                                                                                                                            BOOTSTRAP=true
                                                                                                                                                                                            git switch --orphan "$TARGET"
                                                                                                                                                                                            git commit -m "" --allow-empty --allow-empty-message
                                                                                                                                                                                            git push origin "HEAD:$TARGET"
                                                                                                                                                                                            git fetch origin "+$TARGET:refs/remotes/origin/$TARGET"
                                                                                                                                                                                        fi
                                                                                                                                                                                    fi
                                                                                                                                                                                    jq --null-input --argjson BOOTSTRAP "$BOOTSTRAP" '{ "bootstrap" : $BOOTSTRAP }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                                    if ! git switch --detach "refs/remotes/origin/${ "$" }{BRANCH}" 2>&1 | jq --raw-input '{ "switch" : . }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                                    then
                                                                                                                                                                                        STATUS=false
                                                                                                                                                                                    fi
                                                                                                                                                                                    if [[ "$STATUS" == "true" ]]
                                                                                                                                                                                    then
                                                                                                                                                                                        if ! git rebase "origin/$TARGET" 2>&1 | jq --raw-input '{ "rebase" : . }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                                        then
                                                                                                                                                                                            STATUS=false
                                                                                                                                                                                        fi
                                                                                                                                                                                        if [[ "$STATUS" == "true" ]]
                                                                                                                                                                                        then
                                                                                                                                                                                            jq --null-input '{ "checks" : { } }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                                            while IFS= read -r CHECK
                                                                                                                                                                                            do
                                                                                                                                                                                                export CHECK
                                                                                                                                                                                                if ! check | yq eval --prettyPrint '[.]' >> "$LOG"
                                                                                                                                                                                                then
                                                                                                                                                                                                    STATUS=false
                                                                                                                                                                                                fi
                                                                                                                                                                                            done < <( nix eval --json .#lib.checks | jq -r 'keys[]' )
                                                                                                                                                                                            if [[ "$STATUS" == "true" ]]
                                                                                                                                                                                            then
                                                                                                                                                                                                if ! nix flake check --show-trace --flake ./flake.nix 2>&1 | jq --raw-input '{ "check" : . }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                                                then
                                                                                                                                                                                                    STATUS=false
                                                                                                                                                                                                fi
                                                                                                                                                                                                if [[ "$STATUS" == "true" ]]
                                                                                                                                                                                                then
                                                                                                                                                                                                    if git push origin "HEAD:refs/heads/$TARGET" 2>&1 | jq --raw-input '{ "push" : . }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                                                    then
                                                                                                                                                                                                        git push origin "HEAD:refs/heads/$SUCCESS$BRANCH" > /dev/null 2>&1
                                                                                                                                                                                                    else
                                                                                                                                                                                                        STATUS=false
                                                                                                                                                                                                    fi
                                                                                                                                                                                                fi
                                                                                                                                                                                            fi
                                                                                                                                                                                        fi
                                                                                                                                                                                    fi
                                                                                                                                                                                    if [[ "$STATUS" == "false" ]]
                                                                                                                                                                                    then
                                                                                                                                                                                        git push origin "HEAD:refs/heads/$FAILURE$BRANCH" > /dev/null 2>&1
                                                                                                                                                                                    fi
                                                                                                                                                                                    git push origin "$BRANCH" --delete > /dev/null 2>&1
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
                                                                                                                                                                BEFORE="$( date +%s )"
                                                                                                                                                                LOG="$( mktemp --suffix ".yaml" ${ config.promoter.directory }/temporary/XXXXXXXX )"
                                                                                                                                                                jq --null-input --argjson BEFORE "$BEFORE" '{ "before" : $BEFORE }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                JSON="$( mktemp --suffix ".json" ${ config.promoter.directory }/temporary/XXXXXXXX )"
                                                                                                                                                                jq '.' > "$JSON"
                                                                                                                                                                NAME="$( jq --raw-output ".name" "$JSON" )"
                                                                                                                                                                mkdir --parents "${ config.promoter.directory }/polling/$NAME"
                                                                                                                                                                cd "${ config.promoter.directory }/polling/$NAME"
                                                                                                                                                                if [[ ! -d .git ]]
                                                                                                                                                                then
                                                                                                                                                                    git init 2>&1 | jq --raw-input '{ "git-init" : . }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                fi
                                                                                                                                                                SSH_COMMAND="$( jq --raw-output '.value.committer["ssh-command"]' "$JSON" )"
                                                                                                                                                                git config core.sshCommand "$SSH_COMMAND"
                                                                                                                                                                EMAIL="$( jq --raw-output '.value.committer.email' "$JSON" )"
                                                                                                                                                                git config user.email "$EMAIL"
                                                                                                                                                                NAME="$( jq --raw-output '.value.committer.name' "$JSON" )"
                                                                                                                                                                git config user.name "$NAME"
                                                                                                                                                                git config remote.origin.prune true
                                                                                                                                                                URL="$( jq --raw-output '.value.url' "$JSON" )"
                                                                                                                                                                if ! git remote get-url origin
                                                                                                                                                                then
                                                                                                                                                                    git remote add origin "$URL"
                                                                                                                                                                else
                                                                                                                                                                    git remote set-url origin "$URL"
                                                                                                                                                                fi
                                                                                                                                                                PREPARATION="$( jq --raw-output '.value.branch.preparation' "$JSON" )"
                                                                                                                                                                TARGET="$( jq --raw-output '.value.branch.target' "$JSON" )"
                                                                                                                                                                export TARGET
                                                                                                                                                                SUCCESS="$( jq --raw-output '.value.branch.success' "$JSON" )"
                                                                                                                                                                export SUCCESS
                                                                                                                                                                FAILURE="$( jq --raw-output '.value.branch.failure' "$JSON" )"
                                                                                                                                                                export FAILURE
                                                                                                                                                                if git fetch origin "+refs/heads/$PREPARATION*:refs/remotes/origin/$PREPARATION*" 2>&1 | jq --raw-input '{ "git-fetch" : . }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                then
                                                                                                                                                                    jq --null-input '{ "branches" : { } }' | yq eval --prettyPrint '.' >> "$LOG"
                                                                                                                                                                    while IFS= read -r BRANCH
                                                                                                                                                                    do
                                                                                                                                                                        export BRANCH
                                                                                                                                                                        branch "$BRANCH" | yq eval --prettyPrint '{ strenv(BRANCH) : . }' >> "$LOG"
                                                                                                                                                                    done < <( git for-each-ref --format='%(refname:strip=3)' "refs/remotes/origin/$PREPARATION*" )
                                                                                                                                                                fi
                                                                                                                                                                AFTER="$( date +%s )"
                                                                                                                                                                ELAPSED=$(( AFTER - BEFORE ))
                                                                                                                                                                jq --null-input --argjson AFTER "$AFTER" --argjson ELAPSED "$ELAPSED" --argjson BEFORE "$BEFORE" '{ "after" : $AFTER , "elapsed" : $ELAPSED }' >> "$LOG"
                                                                                                                                                                yq eval --prettyPrint '[.]' "$LOG"
                                                                                                                                                                rm "$JSON" "$LOG"
                                                                                                                                                            '' ;
                                                                                                                                                    }
                                                                                                                                            )
                                                                                                                                        ] ;
                                                                                                                                    text =
                                                                                                                                        let
                                                                                                                                            mapper =
                                                                                                                                                name : value :
                                                                                                                                                    ''
                                                                                                                                                        jq '.' ${ builtins.toFile "repository.json" ( builtins.toJSON { name = name ; value = value ; } ) } | repository | yq eval --prettyPrint '[.]' >> ${ config.promoter.directory }/log.yaml
                                                                                                                                                    '' ;
                                                                                                                                            in builtins.concatStringsSep "\n" ( builtins.attrValues ( builtins.mapAttrs mapper config.promoter.polling ) ) ;
                                                                                                                                }
                                                                                                                        )
                                                                                                                        (
                                                                                                                            pkgs.writeShellApplication
                                                                                                                                {
                                                                                                                                    name = "proceed" ;
                                                                                                                                    runtimeInputs = [ pkgs.coreutils pkgs.flock ] ;
                                                                                                                                    text =
                                                                                                                                        ''
                                                                                                                                            mkdir --parents "${ config.promoter.directory }"
                                                                                                                                            exec 186> "${ config.promoter.directory }/control.lock"
                                                                                                                                            flock -x 186
                                                                                                                                            if [[ ! -f "${ config.promoter.directory }/control.asc" ]]
                                                                                                                                            then
                                                                                                                                                echo POLL > "${ config.promoter.directory }/control.asc"
                                                                                                                                            fi
                                                                                                                                            STATE="$( cat "${ config.promoter.directory }/control.asc" )"
                                                                                                                                            if [[ "$STATE" != "POLL" ]]
                                                                                                                                            then
                                                                                                                                                exit 1
                                                                                                                                            fi
                                                                                                                                        '' ;
                                                                                                                                }
                                                                                                                        )
                                                                                                                    ] ;
                                                                                                                text =
                                                                                                                    ''
                                                                                                                        mkdir --parents "${ config.promoter.directory }"
                                                                                                                        echo "$$" > "${ config.promoter.directory }/control.pid"
                                                                                                                        while proceed
                                                                                                                        do
                                                                                                                            iterate
                                                                                                                        done
                                                                                                                    '' ;
                                                                                                            }
                                                                                                    )
                                                                                                ] ;
                                                                                            text =
                                                                                                ''
                                                                                                    if [[ -e "${ config.promoter.directory }" ]]
                                                                                                    then
                                                                                                        exit 1
                                                                                                    fi
                                                                                                    nohup launch > /dev/null 2>&1 &
                                                                                                '' ;
                                                                                        } ;
                                                                                type = lib.types.package ;
                                                                            } ;
                                                                } ;
                                                            directory = lib.mkOption { default = "/run/promoter" ; type = lib.types.str ; } ;
                                                            polling =
                                                                lib.mkOption
                                                                    {
                                                                        default = { } ;
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
                                                                                                            ssh-command = lib.mkOption { type = lib.types.str ; } ;
                                                                                                            email = lib.mkOption { type = lib.types.str ; } ;
                                                                                                            name = lib.mkOption { type = lib.types.str ; } ;
                                                                                                        } ;
                                                                                                    url = lib.mkOption { type = lib.types.str ; } ;
                                                                                                } ;
                                                                                        } ;
                                                                                in lib.types.attrsOf type ;
                                                                    } ;
                                                        } ;
                                                } ;
                            in
                                {
                                    checks =
                                        {
                                        } ;
                                    implementation = output implementation ;
                                } ;
            } ;
}