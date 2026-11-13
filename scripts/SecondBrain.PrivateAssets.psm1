#requires -Version 7.5
# Private repository assets (asset contracts section 6, #589): cards and workflows of one repository kept in its dossier
# (prompts/catalog.json with prompts/<name>.md, workflows/<name>.json). Keys are namespaced <repo-slug>/<name>, so they never
# collide with or shadow a public code, key or role. A private asset may reference public assets; a public asset never
# references a private one. Workflows are validated here; running them waits for the workflow engine.
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Core.psm1')
Import-Module (Join-Path $PSScriptRoot 'SecondBrain.Messages.psm1')
Add-SBMessages @{
    'private.invalid' = @{it='Asset privato non valido in {0}: {1}';en='Invalid private asset in {0}: {1}'}
    'private.collision' = @{it='L asset privato {0} collide con un asset pubblico o di un altro dossier ({1})';en='Private asset {0} collides with a public or other-dossier asset ({1})'}
    'private.reference' = @{it='{0} cita {1}, che non e un asset pubblico ne di questo dossier';en='{0} references {1}, which is neither public nor in this dossier'}
    'private.public.reference' = @{it='Il file pubblico {0} cita l asset privato {1}';en='Public file {0} references private asset {1}'}
    'private.notfound' = @{it='Nessun asset privato {0} per questo repository';en='No private asset {0} for this repository'}
}
$script:SBPrivateTags=@('role','context','inputs','decisions','procedure','constraints','exit_criteria','output_format')
$script:SBPrivateRequired=@('role','context','inputs','procedure','constraints','exit_criteria','output_format')

function Get-SBRepositorySlug([string]$Repository) {
    # Last path segment of the identity, lowercased, reduced to [a-z0-9-]: github.com/acme/App_One -> app-one.
    $last=(($Repository -split '/')|Where-Object {$_}|Select-Object -Last 1)
    $slug=([string]$last).ToLowerInvariant() -replace '[^a-z0-9-]+','-' -replace '^-+|-+$',''
    if(!$slug){throw (New-SBError 'private.invalid' @($Repository,'repository slug'))}
    $slug
}

function Get-SBPublicAssetNames($PublicCatalog) {
    # Every public ID, code and role: the names a private asset must never reuse or shadow.
    $names=@{}
    foreach($prompt in @($PublicCatalog.prompts)){
        $names[[string]$prompt.id]='public '+$prompt.code;$names[[string]$prompt.code]='public '+$prompt.code
        if($prompt.Contains('role') -and $prompt.role){$names['role:'+[string]$prompt.role]='public '+$prompt.code}
    }
    $names
}

function Assert-SBPrivateCardBody([string]$Text,[string]$Key,[string]$Summary,[string]$Where) {
    $body=$Text.Replace("`r`n","`n")
    $first=($body -split "`n")[0]
    # Header "# <key> <em dash U+2014> <summary>", as for public cards.
    $dash=[string][char]0x2014
    if($first -cne ('# '+$Key+' '+$dash+' '+$Summary.TrimEnd('.'))){throw (New-SBError 'private.invalid' @($Where,'the first line must be "# '+$Key+' '+$dash+' <summary>"'))}
    if($body.Length -gt 3500){throw (New-SBError 'private.invalid' @($Where,'card body above 3,500 characters'))}
    $opened=@([regex]::Matches($body,'(?m)^<([a-z_]+)>[ \t]*$')|ForEach-Object {$_.Groups[1].Value})
    $expected=@($script:SBPrivateTags|Where-Object {$_ -in $opened})
    if(($opened -join ',') -cne ($expected -join ',')){throw (New-SBError 'private.invalid' @($Where,'sections out of order or unknown: '+($opened -join ',')))}
    foreach($tag in $script:SBPrivateRequired){
        $m=[regex]::Match($body,'(?ms)^<'+$tag+'>\n(.*?)\n</'+$tag+'>[ \t]*$')
        if(!$m.Success -or !$m.Groups[1].Value.Trim()){throw (New-SBError 'private.invalid' @($Where,'section '+$tag+' missing or empty'))}
        if($tag -eq 'procedure' -and @([regex]::Matches($m.Groups[1].Value,'(?m)^\d+\. ')).Count -lt 2){throw (New-SBError 'private.invalid' @($Where,'procedure needs at least two numbered steps'))}
    }
}

function Read-SBPrivateAssets {
    # Reads and validates the private cards and workflows of one dossier. A dossier without prompts/ or workflows/ has none.
    param([string]$Dossier,[string]$Repository,$PublicCatalog,[hashtable]$Taken=@{})
    $slug=Get-SBRepositorySlug $Repository
    $public=Get-SBPublicAssetNames $PublicCatalog
    $result=[ordered]@{repository=$Repository;slug=$slug;dossier=$Dossier;prompts=@();workflows=@()}
    $own=@{}
    $claim={param($name,$where)
        if($public.ContainsKey($name)){throw (New-SBError 'private.collision' @($name,$public[$name]))}
        if($Taken.ContainsKey($name) -and $Taken[$name] -cne $Repository){throw (New-SBError 'private.collision' @($name,$Taken[$name]))}
        if($own.ContainsKey($name)){throw (New-SBError 'private.collision' @($name,'duplicate in '+$where))}
        $own[$name]=$where
    }
    $keyPattern='^'+[regex]::Escape($slug)+'/[a-z0-9][a-z0-9-]{1,40}$'
    $catalogPath=Join-Path $Dossier 'prompts/catalog.json'
    $prompts=@()
    if(Test-Path -LiteralPath $catalogPath -PathType Leaf){
        $catalog=Read-SBJson $catalogPath $null
        if($catalog -isnot [Collections.IDictionary] -or $catalog['schemaVersion'] -ne 1 -or $catalog['repository'] -cne $Repository -or @($catalog.Keys|Where-Object {$_ -cnotin @('schemaVersion','repository','prompts')}).Count){throw (New-SBError 'private.invalid' @($catalogPath,'root needs schemaVersion 1, repository and prompts'))}
        foreach($card in @($catalog['prompts'])){
            if($null -eq $card){continue}
            $where='prompts/catalog.json'
            $fields=@('id','key','summary','mode','destructive','target','role','revision','status','file','related')
            if($card -isnot [Collections.IDictionary] -or @($card.Keys|Where-Object {$_ -cnotin $fields}).Count){throw (New-SBError 'private.invalid' @($where,'card fields'))}
            if([string]$card['id'] -cnotmatch '^pmt-[0-9a-f]{8}$'){throw (New-SBError 'private.invalid' @($where,'id must be pmt- plus 8 hex digits'))}
            if([string]$card['key'] -cnotmatch $keyPattern){throw (New-SBError 'private.invalid' @($where,$card.id+': key must be '+$slug+'/<name>'))}
            $summary=[string]$card['summary']
            if(!$summary -or $summary.Length -gt 82 -or $summary -notmatch '\.$' -or $summary -match '[\r\n]'){throw (New-SBError 'private.invalid' @($where,$card.key+': summary of at most 82 characters ending with a period'))}
            if($card['mode'] -cnotin @('read','verify','write') -or $card['destructive'] -isnot [bool] -or $card['target'] -cne 'repository'){throw (New-SBError 'private.invalid' @($where,$card.key+': mode, destructive (boolean) and target=repository'))}
            $revisionOk=($card['revision'] -is [int] -or $card['revision'] -is [long]) -and [long]$card['revision'] -ge 1
            if($card['status'] -cnotin @('draft','active','deprecated','retired') -or !$revisionOk){throw (New-SBError 'private.invalid' @($where,$card.key+': status and positive revision'))}
            $name=([string]$card.key -split '/',2)[1]
            if($card['file'] -cne ($name+'.md')){throw (New-SBError 'private.invalid' @($where,$card.key+': file must be '+$name+'.md'))}
            & $claim ([string]$card.id) $where
            & $claim ([string]$card.key) $where
            if($card.Contains('role') -and $card.role){& $claim ('role:'+[string]$card.role) $where}
            $file=Join-Path $Dossier ('prompts/'+$card.file)
            if(!(Test-Path -LiteralPath $file -PathType Leaf)){throw (New-SBError 'private.invalid' @($where,$card.key+': card file missing'))}
            Assert-SBPrivateCardBody (Read-SBText $file) ([string]$card.key) $summary ('prompts/'+$card.file)
            $prompts+=,$card
        }
    }
    $workflowDir=Join-Path $Dossier 'workflows'
    $workflows=@()
    if(Test-Path -LiteralPath $workflowDir -PathType Container){
        foreach($file in @(Get-ChildItem -LiteralPath $workflowDir -File -Filter '*.json'|Sort-Object Name)){
            $where='workflows/'+$file.Name
            $flow=Read-SBJson $file.FullName $null
            $fields=@('schemaVersion','id','key','title','revision','status','inputs','steps','outputs')
            if($flow -isnot [Collections.IDictionary] -or $flow['schemaVersion'] -ne 1 -or @($flow.Keys|Where-Object {$_ -cnotin $fields}).Count){throw (New-SBError 'private.invalid' @($where,'workflow fields'))}
            if([string]$flow['id'] -cnotmatch '^wfl-[0-9a-f]{8}$'){throw (New-SBError 'private.invalid' @($where,'id must be wfl- plus 8 hex digits'))}
            if([string]$flow['key'] -cnotmatch $keyPattern -or ([string]$flow.key -split '/',2)[1]+'.json' -cne $file.Name){throw (New-SBError 'private.invalid' @($where,'key must be '+$slug+'/'+$file.BaseName))}
            $flowRevisionOk=($flow['revision'] -is [int] -or $flow['revision'] -is [long]) -and [long]$flow['revision'] -ge 1
            if(![string]$flow['title'] -or $flow['status'] -cnotin @('draft','active','deprecated','retired') -or !$flowRevisionOk){throw (New-SBError 'private.invalid' @($where,'title, status and positive revision'))}
            & $claim ([string]$flow.id) $where
            & $claim ([string]$flow.key) $where
            $workflows+=,$flow
        }
    }
    # References: cards cite public or same-dossier cards; workflow steps reference public cards or same-dossier cards and workflows.
    $publicIds=@{};foreach($p in @($PublicCatalog.prompts)){$publicIds[[string]$p.id]=$p}
    $privateCards=@{};foreach($c in $prompts){$privateCards[[string]$c.id]=$c}
    $privateFlows=@{};foreach($w in $workflows){$privateFlows[[string]$w.id]=$w}
    foreach($card in $prompts){
        foreach($ref in @($(if($card.Contains('related')){$card.related}else{@()}))){
            if($ref -ceq $card.id -or (!$publicIds.ContainsKey([string]$ref) -and !$privateCards.ContainsKey([string]$ref))){throw (New-SBError 'private.reference' @($card.key,$ref))}
        }
    }
    foreach($flow in $workflows){
        $slugs=@{}
        $steps=@($flow['steps'])
        if(!$steps.Count){throw (New-SBError 'private.invalid' @($flow.key,'a workflow needs steps'))}
        foreach($step in $steps){
            if($step -isnot [Collections.IDictionary] -or @($step.Keys|Where-Object {$_ -cnotin @('step','ref','kind','gate','with','options')}).Count){throw (New-SBError 'private.invalid' @($flow.key,'step fields'))}
            if([string]$step['step'] -cnotmatch '^[a-z0-9][a-z0-9-]{0,31}$' -or $slugs.ContainsKey([string]$step.step)){throw (New-SBError 'private.invalid' @($flow.key,'step slugs unique, lowercase'))}
            $slugs[[string]$step.step]=$true
            if($step['kind'] -cnotin @('required','optional','choice') -or $step['gate'] -cnotin @('auto','confirm')){throw (New-SBError 'private.invalid' @($flow.key,$step.step+': kind and gate'))}
            $refs=if($step.kind -eq 'choice'){@($step['options'])}else{@($step['ref'])}
            if($step.kind -eq 'choice' -and ($refs.Count -lt 2 -or $refs.Count -gt 4)){throw (New-SBError 'private.invalid' @($flow.key,$step.step+': a choice step lists 2 to 4 options'))}
            foreach($ref in $refs){
                $ref=[string]$ref
                $target=if($publicIds.ContainsKey($ref)){$publicIds[$ref]}elseif($privateCards.ContainsKey($ref)){$privateCards[$ref]}elseif($privateFlows.ContainsKey($ref)){$null}else{throw (New-SBError 'private.reference' @($flow.key,$ref))}
                if($ref -ceq $flow.id){throw (New-SBError 'private.invalid' @($flow.key,'a workflow cannot reference itself'))}
                if($target -and $target.Contains('destructive') -and $target.destructive -and $step.gate -ne 'confirm'){throw (New-SBError 'private.invalid' @($flow.key,$step.step+': a destructive step needs gate confirm'))}
            }
        }
    }
    # Nesting: at most depth 2 (a workflow may call workflows that call only cards) and no cycles.
    foreach($flow in $workflows){
        foreach($step in @($flow.steps)){
            foreach($ref in @($(if($step.kind -eq 'choice'){$step.options}else{@($step.ref)}))){
                if(!$privateFlows.ContainsKey([string]$ref)){continue}
                foreach($inner in @($privateFlows[[string]$ref].steps)){
                    foreach($innerRef in @($(if($inner.kind -eq 'choice'){$inner.options}else{@($inner.ref)}))){
                        if($privateFlows.ContainsKey([string]$innerRef)){throw (New-SBError 'private.invalid' @($flow.key,'workflow nesting deeper than 2 or a cycle through '+$innerRef))}
                    }
                }
            }
        }
    }
    $result.prompts=@($prompts);$result.workflows=@($workflows)
    $result
}

function Get-SBPrivateAssetDossiers([string]$BrainRoot) {
    # Active repository dossiers that hold private assets (prompts/catalog.json or workflows/).
    $projects=Join-Path $BrainRoot '01-projects'
    if(!(Test-Path -LiteralPath $projects -PathType Container)){return @()}
    @(Get-ChildItem -LiteralPath $projects -Directory|Where-Object {
        (Test-Path -LiteralPath (Join-Path $_.FullName 'repository.json') -PathType Leaf) -and
        ((Test-Path -LiteralPath (Join-Path $_.FullName 'prompts/catalog.json') -PathType Leaf) -or (Test-Path -LiteralPath (Join-Path $_.FullName 'workflows') -PathType Container))
    }|ForEach-Object {
        $meta=Read-SBJson (Join-Path $_.FullName 'repository.json') $null
        [ordered]@{dossier=$_.FullName;repository=[string]$meta.identity}
    })
}

function Test-SBPrivateAssets {
    # Validates every dossier's private assets against the public catalog and each other, then checks that no public file
    # (direttive/: catalogs, cards, workflows, agent templates, directives) cites a private ID or key. Throws on the first error.
    param([string]$BrainRoot,$PublicCatalog)
    $taken=@{};$sets=@()
    foreach($entry in @(Get-SBPrivateAssetDossiers $BrainRoot)){
        $set=Read-SBPrivateAssets -Dossier $entry.dossier -Repository $entry.repository -PublicCatalog $PublicCatalog -Taken $taken
        foreach($item in @($set.prompts)+@($set.workflows)){$taken[[string]$item.id]=$entry.repository;$taken[[string]$item.key]=$entry.repository}
        $sets+=,$set
    }
    $tokens=@($taken.Keys|Where-Object {$_ -notlike 'role:*'})
    $findings=@(Find-SBPrivateReferences $BrainRoot $tokens)
    if($findings.Count){throw (New-SBError 'private.public.reference' @($findings[0].path,$findings[0].token))}
    [ordered]@{dossiers=$sets.Count;prompts=@($sets|ForEach-Object {@($_.prompts)}).Count;workflows=@($sets|ForEach-Object {@($_.workflows)}).Count;publicReferences=0}
}

function Get-SBPrivateAssetTokens([string]$BrainRoot) {
    # IDs and keys of every private asset on this workstation, read without full validation (used by the publication scan).
    $tokens=@()
    foreach($entry in @(Get-SBPrivateAssetDossiers $BrainRoot)){
        $catalog=Join-Path $entry.dossier 'prompts/catalog.json'
        if(Test-Path -LiteralPath $catalog -PathType Leaf){
            try{foreach($card in @((Read-SBJson $catalog $null).prompts)){if($card){$tokens+=@([string]$card.id,[string]$card.key)}}}catch{Write-Verbose $_.Exception.Message}
        }
        $dir=Join-Path $entry.dossier 'workflows'
        if(Test-Path -LiteralPath $dir -PathType Container){
            foreach($file in @(Get-ChildItem -LiteralPath $dir -File -Filter '*.json')){try{$flow=Read-SBJson $file.FullName $null;$tokens+=@([string]$flow.id,[string]$flow.key)}catch{Write-Verbose $_.Exception.Message}}
        }
    }
    @($tokens|Where-Object {$_}|Select-Object -Unique)
}

function Find-SBPrivateReferences([string]$BrainRoot,[string[]]$Tokens) {
    if(!@($Tokens).Count){return @()}
    $root=Join-Path $BrainRoot 'direttive'
    if(!(Test-Path -LiteralPath $root -PathType Container)){return @()}
    $hits=@()
    # Historical proposals are excluded (asset contracts section 7, rule 8).
    foreach($file in @(Get-ChildItem -LiteralPath $root -File -Recurse -Include '*.md','*.json'|Where-Object {$_.FullName -notmatch '[\\/]proposals[\\/]'})){
        $text=Read-SBText $file.FullName
        foreach($token in $Tokens){
            if($text.Contains($token)){$hits+=[ordered]@{path=[IO.Path]::GetRelativePath($BrainRoot,$file.FullName).Replace('\','/');token=$token}}
        }
    }
    $hits
}

function Resolve-SBPrivatePrompt($Set,[string]$Key) {
    $found=@(@($Set.prompts)|Where-Object {$_.id -ceq $Key -or $_.key -ceq $Key})
    if($found.Count -ne 1){throw (New-SBError 'private.notfound' @($Key))}
    $found[0]
}

function Format-SBPrivatePromptList($Set) {
    # Listed only for their own repository; draft and retired cards stay hidden (lifecycle, section 1.3).
    $visible=@(@($Set.prompts)|Where-Object {$_.status -in @('active','deprecated')})
    $flows=@(@($Set.workflows)|Where-Object {$_.status -in @('active','deprecated')})
    if(!$visible.Count -and !$flows.Count){return ''}
    $lines=@('','Private cards of '+$Set.repository+':')
    foreach($card in $visible){$lines+=('  '+$card.key+' | '+$card.summary+' ('+$card.mode+$(if($card.destructive){', destructive'}else{''})+$(if($card.status -eq 'deprecated'){', deprecated'}else{''})+')')}
    if($flows.Count){$lines+='Private workflows (validated; running them needs the workflow engine):';foreach($flow in $flows){$lines+=('  '+$flow.key+' | '+$flow.title)}}
    ($lines -join "`n")+"`n"
}

function New-SBPrivatePromptComposition($Set,$Card,[string]$Objective) {
    if($Card.status -notin @('active','deprecated')){throw (New-SBError 'private.notfound' @($Card.key))}
    $body=(Read-SBText (Join-Path $Set.dossier ('prompts/'+$Card.file))).Replace("`r`n","`n").TrimEnd()
    $head='<prompt key="'+$Card.key+'" id="'+$Card.id+'" mode="'+$Card.mode+'" target="repository" private="true">'
    $parts=@($head,'<task>')
    $parts+=$(if($Objective){'Objective: '+$Objective}else{'Derive the objective from the request and the conversation. If an essential input cannot be found in the files, ask one targeted question.'})
    $parts+=@('</task>',('Repository: '+$Set.repository),$body)
    if($Card.status -eq 'deprecated'){$parts+='Notice: this private card is deprecated.'}
    $parts+='</prompt>'
    ($parts -join "`n")+"`n"
}

Export-ModuleMember -Function @('Get-SBRepositorySlug','Read-SBPrivateAssets','Get-SBPrivateAssetDossiers','Test-SBPrivateAssets','Get-SBPrivateAssetTokens','Find-SBPrivateReferences','Resolve-SBPrivatePrompt','Format-SBPrivatePromptList','New-SBPrivatePromptComposition')
