#!/bin/bash

case $1 in
    gentest)
        cd ftplugin/
        langs=`ls -d * | grep -v "^_" | awk '{printf($1" ");}'`
        cd -

        echo "vim -c \"XPTtestAll $langs\"" >test.bat
        exit
        ;;

    "")
        mode=""
        echo "export"
        ;;

    "test")
        mode=test
        echo "export"
        ;;

    *)
        echo "error"
        exit -1
        ;;

esac


CurrentDir=$PWD
ParentDir=${PWD%/*}
githash=`git log --max-count=1 --format=%h`
today=`date +%y%m%d`
ver=`cat VERSION`.$today-$githash
build_name=build-$today-$githash

dev_branch=dev
build_branch=master


compact() {
    local file=$1

    echo remove Logs/Comments/Empty_Lines from $file

    grep -v "call s:log.\(Log\|Debug\)(" $file |\
        grep -v "^ *Assert " |\
        grep -v "^ *\"" |\
        grep -v "^ *$" |\
        sed 's/ *" *{{{//; s/ *" *}}}//' > .tmp

    mv .tmp $file
}

create_tgz() {
    rm -rf $ParentDir/xpt && mkdir $ParentDir/xpt && cp -R ./* $ParentDir/xpt/
    cd $ParentDir/xpt && tar -czf ../xpt-$ver.tgz *
    cd $CurrentDir
}

build_for_release () {
    check_cur_branch \
        && create_build_branch \
        && clean_files \
        && remove_tests \
        && compact_files \
        && generate_version \
        && commit_build \
        && create_tgz \
        && update_built_branch \
        && echo "Done"
}

build_for_test () {
    check_cur_branch \
        && git checkout $githash \
        && clean_files \
        && compact_files \
        && generate_version \
        && commit_build \
        && vim -c 'call xpt#unittest#Runall() | call getchar() | qa' \
        && echo "Done building for test"
}

check_cur_branch() {
    local cur_branch=$(git symbolic-ref HEAD 2>/dev/null | cut -c 12-)

    echo $cur_branch

    if [ ".$cur_branch" != ".$dev_branch" ]; then
        echo "not on $dev_branch!!"
        return -1;
    fi
}

create_build_branch() {
    git checkout -b $build_name || { echo "Failed to create branch $build_name"; return 1; }
}

clean_files() {
    cat $CurrentDir/$0 | awk '/^# __TO_REMOVE__/,/^# __TO_REMOVE__ END/{ if ( $1 != "#" ) print $0; }' | while read f; do git rm -rf $f; done
    git rm `find . -name "test.page*"`
    rm `find . -name "*.xpt.vimc"`
    return 0
}

remove_tests() {
    git rm -rf test/
    git rm -rf autoload/xpt/ut/
    git rm -rf autoload/xpt/unittest.vim
}

compact_files() {

    for file in `find {plugin,autoload}/ -name *.vim | grep -v "/debug\.vim$"`;do
        compact $file
    done
}

generate_version() {

    mv plugin/xptemplate.vim .tmp
    cat > plugin/xptemplate.vim <<-END
	" GetLatestVimScripts: 2611 1 :AutoInstall: xpt.tgz
	" VERSION: $ver
	END
    cat .tmp >> plugin/xptemplate.vim && rm .tmp

}

commit_build() {
    git commit -a -m "$build_name"
}

update_built_branch(){

    local tree_hash=$(git_obj_get_tree "$build_name")
    local built_commit_hash=$(echo "$build_name" | git commit-tree $tree_hash -p $build_branch -p $dev_branch)
    git update-ref refs/heads/$build_branch $built_commit_hash

    git checkout $dev_branch \
        && git branch -D $build_name

}

git_obj_get_tree () {
    git cat-file -p "$1" | head -n1 | awk '{print $2}'
}

if [ "$mode" == "test" ]; then
    build_for_test
else
    build_for_release
fi
exit

# __TO_REMOVE__
xpt.ex
plugin/xptemplateTest.vim
plugin/xptTestKey.vim
plugin/xptemplate.importer.vim
xpt.testall.*
genfile.vim
doc/tags
xpt.files.txt
bench.vim
test.bat
test.sh
tags
todo
experiment/
resource/
_script/
VERSION
# __TO_REMOVE__ END
