#!/bin/zsh
# CLI regression of Secretariat 1.10 against an isolated test home. Artificial values only.
set -u
B=${1:-$(dirname $0)/../dist/Secretariat.app/Contents/MacOS/Secretariat}; B=${B:A}
T=$(mktemp -d "${TMPDIR:-/tmp}/secretariat-regress.XXXX")
export SECRETARIAT_HOME=$T/vault; mkdir -m 700 $SECRETARIAT_HOME
P=$T/proj; mkdir -p $P; cd $P; git init -q .
V1="artificial-a-$RANDOM$RANDOM"; V2="artificial-b-$RANDOM$RANDOM"
pass=0; fail=0
ok() { if eval "$2"; then echo "PASS $1"; pass=$((pass+1)); else echo "FAIL $1"; fail=$((fail+1)); fi }

printf 'A_KEY=%s\nB_KEY=%s\n' $V1 $V2 > $T/seed.env
out=$($B import $T/seed.env A_KEY=regress/acct/a_key B_KEY=regress/acct/b_key --json 2>&1); rm $T/seed.env
ok "import: values in, names only out" '[[ $out != *$V1* && $out != *$V2* ]] && $B items --json | grep -q regress/acct'
ok "items --json never shows values" '! $B items --json | grep -q artificial-'
$B item create regress/acct2 --kind api --set api_key=$V1 --json >/dev/null 2>&1; ok "item create via CLI" '$B item show regress/acct2 --json | grep -q api_key'
ok "get refuses secrets" '! $B get regress/acct/a_key >/dev/null 2>&1'
$B profile create rp --dir $P --json >/dev/null; $B profile bind rp A_KEY regress/acct/a_key --json >/dev/null; $B profile bind rp B_KEY regress/acct/b_key --json >/dev/null
ok "profiles/describe schema" '$B profiles --json | grep -q "\"rp\"" && $B describe rp --json | grep -q A_KEY'
ok "check ready, no values" 'c=$($B check rp --json); [[ $c == *true* && $c != *artificial* ]]'
ok "profile which" '$B profile which $P | grep -q rp'
ok "run passes values" '[[ $($B run rp --no-mask -- sh -c "echo \$A_KEY:\$B_KEY") == "$V1:$V2" ]]'
ok "run keeps stdin" '[[ $(echo hallo | $B run rp -- cat) == hallo ]]'
$B run rp -- sh -c 'exit 7'; ok "run keeps exit code" '[[ $? == 7 ]]'
ok "run masks values in pipe" '! $B run rp -- sh -c "echo \$A_KEY" | grep -q artificial-'
$B item create regress/tmp --kind api --set api_key=$V1 --json >/dev/null; $B profile bind rp C_KEY regress/tmp/api_key --json >/dev/null
$B item set regress/tmp --unset api_key --json >/dev/null 2>&1
ok "missing value: nothing starts, non-zero exit" '! $B run rp -- touch $T/started 2>/dev/null; [[ ! -e $T/started ]]'
$B profile unbind rp C_KEY >/dev/null 2>&1; $B item delete regress/tmp >/dev/null 2>&1
printf 'FILECONTENT-%s' $V2 > $T/key.p8; $B import-file $T/key.p8 regress/acct/key_file --json >/dev/null; rm $T/key.p8
$B profile bind rp KEY_FILE regress/acct/key_file --json >/dev/null
ok "file field as temp 0600 file, removed after" 'f=$($B run rp --no-mask -- sh -c "stat -f %Lp \$KEY_FILE; cat \$KEY_FILE; echo; echo \$KEY_FILE"); [[ ${f[(f)1]} == 600 && ${f[(f)2]} == FILECONTENT-$V2 && ! -e ${f[(f)3]} ]]'
$B field move regress/acct/b_key regress/acct/b_moved --json >/dev/null
ok "field move keeps value and binding" '[[ $($B run rp --no-mask -- sh -c "echo \$B_KEY") == $V2 ]]'
$B item rename regress/acct regress/renamed --json >/dev/null
ok "item rename keeps profile" '[[ $($B run rp --no-mask -- sh -c "echo \$A_KEY") == $V1 ]]'
echo 'K={{ regress/renamed/a_key }}' > $T/tpl; echo out.env > .gitignore
ok "inject into ignored file" '$B inject $T/tpl --out out.env >/dev/null && grep -q "K=$V1" out.env'
ok "inject refuses tracked file" 'git add .gitignore; touch tracked.env; git add tracked.env; ! $B inject $T/tpl --out tracked.env >/dev/null 2>&1'
$B target add rt --command "cat > $T/pushed-{var}" --json >/dev/null; $B target map rt A_KEY regress/renamed/a_key >/dev/null
ok "target never → push → current" '$B targets --json | grep -q never && $B push rt >/dev/null && [[ $(cat $T/pushed-A_KEY) == $V1 ]] && $B targets --json | grep -q current'
printf 'X=%s\n' $V1 > $P/.env
ok "scan finds stored value by name only" 's=$($B scan $P --json); [[ $s == *A_KEY* || $s == *X* ]] && [[ $s != *$V1* ]]'
rm $P/.env
ok "instructions + setup dry-run" '$B setup rp --dry-run --json | grep -q AGENTS'
$B setup rp --json >/dev/null; $B setup rp --json >/dev/null
ok "setup idempotent marker blocks" '[[ $(grep -c "secretariat" AGENTS.md) -ge 1 && $(grep -c "BEGIN" AGENTS.md) -le 1 ]]'
ok "log has names only" '! $B log --lines 200 | grep -q artificial-'
ok "item in use protected" '! $B item delete regress/renamed >/dev/null 2>&1'
$B target delete rt >/dev/null; $B profile delete rp >/dev/null
for i in regress/renamed regress/acct2; do $B item delete $i >/dev/null; done
ok "cleanup: test home empty" '[[ $($B items --json | tr -d " \n") == *\"items\":\[\]* ]]'
rm -rf $T
echo "RESULT pass=$pass fail=$fail"
