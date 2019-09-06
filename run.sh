#!/usr/bin/env bash

### BEGIN ###
# Author: idevz
# Since: 11:14:03 2019/09/05
# Description:       for openresty learning
# run          ./run.sh
#
# Environment variables that control this script:
# NGX_EXEC_FILE=${BASE_DIR}/objs/$(uname | tr '[:upper:]' '[:lower:]')_nginx
### END ###

set -ex
BASE_DIR=$(dirname $(cd $(dirname "$0") && pwd -P)/$(basename "$0"))
LUAJIT_VERSION=${LV:-"2.1-20190626"}
NGX_VERSION=${NV:-"1.17.1"}
NGX_DEVEL_KIT_VERSION=${NDKV:-"0.3.1"}
NGX_LUA_VERSION=${NLV:-"0.10.15"}
NGX_STREAM_LUA_VERSION=${NSLV:-"0.0.7"}
LUA_RESTY_CORE_VERSION=${LRCV:-"0.1.17"}
LUA_RESTY_LRUCACHE_VERSION=${LRLV:-"0.09"}

function or4k::helper::mv() {
    local tar_tmp_dir=${BASE_DIR}/tmp
    [ ! -d ${tar_tmp_dir} ] && mkdir ${tar_tmp_dir}
    local tarball=${1}
    local dir_name=${2}
    local is_mv_to_base_dir=${3}
    tar zxf ${tarball} -C ${tar_tmp_dir}
    if [ ! -z ${is_mv_to_base_dir} ]; then
        mv ${tar_tmp_dir}/$(ls ${tar_tmp_dir})/* ${BASE_DIR}/
        rm -rf ${tar_tmp_dir}/$(ls ${tar_tmp_dir})/
    else
        mv ${tar_tmp_dir}/$(ls ${tar_tmp_dir}) ${BASE_DIR}/${dir_name}
    fi
    return 0
}

function or4k::helper::download_pkg() {
    local url=${1}
    local src_file=${2}
    [ -f ${src_file} ] && return 0
    curl -fSL ${url} -o ${src_file}
}

function or4k::init::prepkgs() {
    local srcs_dir=${BASE_DIR}/srcs
    [ ! -d "${srcs_dir}" ] && mkdir "${srcs_dir}"
    local patches_dir=${BASE_DIR}/patches
    [ ! -d "${patches_dir}" ] && mkdir "${patches_dir}"
    for c in \
        "http://nginx.org/download/nginx-${NGX_VERSION}.tar.gz \
        ${srcs_dir}/nginx-${NGX_VERSION}.tar.gz" \
        "https://github.com/openresty/luajit2/archive/v${LUAJIT_VERSION}.tar.gz \
        ${srcs_dir}/luajit-v${LUAJIT_VERSION}.tar.gz" \
        "https://api.github.com/repos/simplresty/ngx_devel_kit/tarball/v${NGX_DEVEL_KIT_VERSION} \
        ${srcs_dir}/ngx_devel_kit-v${NGX_DEVEL_KIT_VERSION}.tar.gz" \
        "https://api.github.com/repos/openresty/lua-nginx-module/tarball/v${NGX_LUA_VERSION} \
        ${srcs_dir}/lua-nginx-module-v${NGX_LUA_VERSION}.tar.gz" \
        "https://api.github.com/repos/openresty/stream-lua-nginx-module/tarball/v${NGX_STREAM_LUA_VERSION} \
        ${srcs_dir}/stream-lua-nginx-module-v${NGX_STREAM_LUA_VERSION}.tar.gz" \
        "https://api.github.com/repos/openresty/lua-resty-core/tarball/v${LUA_RESTY_CORE_VERSION} \
        ${srcs_dir}/lua-resty-core-v${LUA_RESTY_CORE_VERSION}.tar.gz" \
        "https://api.github.com/repos/openresty/lua-resty-lrucache/tarball/v${LUA_RESTY_LRUCACHE_VERSION} \
        ${srcs_dir}/lua-resty-lrucache-v${LUA_RESTY_LRUCACHE_VERSION}.tar.gz" \
        "https://raw.githubusercontent.com/openresty/openresty/master/patches/nginx-${NGX_VERSION}-privileged_agent_process.patch \
        ${patches_dir}/nginx-${NGX_VERSION}-privileged_agent_process.patch"; do
        or4k::helper::download_pkg ${c}
    done
}

function or4k::init::untar() {
    local srcs_dir=${BASE_DIR}/srcs
    for c in \
        "${srcs_dir}/nginx-${NGX_VERSION}.tar.gz \
        nginx-${NGX_VERSION} yes" \
        "${srcs_dir}/luajit-v${LUAJIT_VERSION}.tar.gz \
        luajit-v${LUAJIT_VERSION}" \
        "${srcs_dir}/ngx_devel_kit-v${NGX_DEVEL_KIT_VERSION}.tar.gz \
        ngx_devel_kit-v${NGX_DEVEL_KIT_VERSION}" \
        "${srcs_dir}/lua-nginx-module-v${NGX_LUA_VERSION}.tar.gz \
        lua-nginx-module-v${NGX_LUA_VERSION}" \
        "${srcs_dir}/stream-lua-nginx-module-v${NGX_STREAM_LUA_VERSION}.tar.gz \
        stream-lua-nginx-module-v${NGX_STREAM_LUA_VERSION}"; do
        or4k::helper::mv ${c}
    done
}

function or4k::init::patch_ngx() {
    patch -p1 <${BASE_DIR}/patches/nginx-${NGX_VERSION}-privileged_agent_process.patch
}

function or4k::install::luajit() {
    local luajit_dirname=luajit-v${LUAJIT_VERSION}
    local luajit_src=${BASE_DIR}/${luajit_dirname}
    local luajit_install_path=/usr/local/${luajit_dirname}
    [ -d ${luajit_install_path} ] && sudo rm -rf ${luajit_install_path}
    cd ${luajit_src}
    make clean
    make CCDEBUG=' -g' -j4 \
        PREFIX="${luajit_install_path}" \
        MACOSX_DEPLOYMENT_TARGET=10.6 \
        XCFLAGS='-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT -fno-standalone-debug' \
        CCOPT=' -O0 -fomit-frame-pointer'
    sudo make install \
        PREFIX="${luajit_install_path}" \
        MACOSX_DEPLOYMENT_TARGET=10.6
    cd -
}

function or4k::install::ngx_configure() {
    local openssl_lib_path="/usr/local/Cellar/openssl/1.0.2s/lib"
    local pcre_lib_path="/usr/local/Cellar/pcre/8.43/lib/"
    local ngx_lua_src="${BASE_DIR}/lua-nginx-module-v${NGX_LUA_VERSION}"
    local stream_lua_src="${BASE_DIR}/stream-lua-nginx-module-v${NGX_STREAM_LUA_VERSION}"
    local ngx_devel_kit_src="${BASE_DIR}/ngx_devel_kit-v${NGX_DEVEL_KIT_VERSION}"

    local luajit_install_path=/usr/local/luajit-v${LUAJIT_VERSION}
    export LUAJIT_LIB=${luajit_install_path}/lib
    export LUAJIT_INC=${luajit_install_path}/include/luajit-2.1

    cd ${BASE_DIR}
    # make clean
    ./configure \
        --prefix="${BASE_DIR}/run_path" \
        --with-debug --with-cc-opt='-O0 -g' \
        --with-ld-opt="-Wl,-rpath,/usr/local/${LUAJIT_SRC_DIR}/lib \
        -L ${openssl_lib_path} -L ${pcre_lib_path}" \
        --with-cc-opt="-I/usr/local/opt/openssl/include/ \
        -I/usr/local/opt/pcre/include/" \
        --add-module="${ngx_devel_kit_src}" \
        --add-module="${stream_lua_src}" \
        --add-module="${ngx_lua_src}" \
        --with-http_realip_module \
        --with-http_secure_link_module \
        --with-http_ssl_module \
        --with-http_stub_status_module \
        --with-http_sub_module \
        --with-http_v2_module \
        --with-stream \
        --with-stream_ssl_module \
        --with-threads

    cd -
}

function or4k::install::ngx_build() {
    local run_path_logs=${BASE_DIR}/run_path/logs
    local run_path_ngxconf=${BASE_DIR}/run_path/conf
    make -j 4
    [ ! -d "${run_path_logs}" ] && mkdir -p "${run_path_logs}"
    touch "${run_path_logs}/error.log"
    [ ! -d "${run_path_ngxconf}" ] && mkdir -p "${run_path_ngxconf}"
    [ ! -f "${run_path_ngxconf}/nginx.conf" ] && cp "${BASE_DIR}/conf/nginx.conf" "${run_path_ngxconf}/nginx.conf"
    cp "${BASE_DIR}/conf/mime.types" "${run_path_ngxconf}/mime.types"
}

function or4k::install::ngx_configure_and_build() {
    or4k::install::ngx_configure
    or4k::install::ngx_build
}

function or4k::install::sweep() {
    for c in CHANGES CHANGES.ru LICENSE Makefile \
        README auto tmp man objs src \
        compile_commands.json conf configure contrib html \
        lua-nginx-module-v${NGX_LUA_VERSION} \
        stream-lua-nginx-module-v${NGX_STREAM_LUA_VERSION} \
        luajit-v${LUAJIT_VERSION} \
        ngx_devel_kit-v${NGX_DEVEL_KIT_VERSION}; do
        rm -rf ${c}
    done
}

function or4k::or::resty_core() {
    local srcs_dir=${BASE_DIR}/srcs
    tar zxf "${srcs_dir}/lua-resty-core-v${LUA_RESTY_CORE_VERSION}.tar.gz" \
        -C "${BASE_DIR}/tmp"
    cp -R ${BASE_DIR}/tmp/$(ls ${BASE_DIR}/tmp)/lib/* "${BASE_DIR}/lua/"
    rm -rf ${BASE_DIR}/tmp/*
    tar zxf "${srcs_dir}/lua-resty-lrucache-v${LUA_RESTY_LRUCACHE_VERSION}.tar.gz" \
        -C "${BASE_DIR}/tmp"
    cp -R ${BASE_DIR}/tmp/$(ls ${BASE_DIR}/tmp)/lib/resty/* "${BASE_DIR}/lua/resty/"
    rm -rf ${BASE_DIR}/tmp
}

do_what=${1}
shift

case ${do_what} in
t | test)
    # or4k::init::prepkgs
    or4k::or::resty_core
    # or4k::init::prepkgs
    # or4k::helper::mv ${BASE_DIR}/srcs/lua-resty-core-v${LUA_RESTY_CORE_VERSION}.tar.gz \
    #     lua-resty-core
    ;;
i | init)
    [ ! -d "${BASE_DIR}/srcs" ] && or4k::init::prepkgs
    or4k::init::untar
    or4k::init::patch_ngx
    ;;
l | install_luajit)
    or4k::install::luajit
    ;;
c | ngx_configure)
    or4k::install::ngx_configure
    ;;
b)
    or4k::install::ngx_build
    ;;
gcd | gen_compilation_database_json)
    # compilation database json came from Clang world
    # which contain the informations aoubt file path, compilation flags and so on

    # we use compiledb tool to generate this json file from Makefile
    # clion using this file to debug Makefile object(which was must be CMakelists object)
    # pip install compiledb
    compiledb -n make
    ;;
cb | ngx_configure_and_build)
    or4k::install::ngx_configure_and_build
    ;;
s | sweep)
    or4k::install::sweep
    ;;
resty)
    or4k::or::resty_core
    ;;
all)
    or4k::install::sweep
    [ ! -d "${BASE_DIR}/srcs" ] && or4k::init::prepkgs
    or4k::init::untar
    or4k::init::patch_ngx
    or4k::install::ngx_configure
    compiledb -n make
    or4k::install::ngx_build
    or4k::or::resty_core
    ;;
*)
    echo "
Usage:

	./run.sh options [arguments]

The options are:

	lua       install luajithttps://github.com/iresty/lua-resty-balancerhttps://github.com/iresty/lua-resty-balancer
	c         configure nginx
	b         build nginx after configure
	cb        configure and build nginx
"
    ;;
esac
