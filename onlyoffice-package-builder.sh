#!/bin/bash

#######################################################################
# Сборщик пакетов OnlyOffice

# Copyright (C) 2024 BTACTIC, SCCL

# Эта программа является свободным программным обеспечением: вы можете распространять и/или модифицировать
# её на условиях Стандартной общественной лицензии GNU в том виде, в каком она была опубликована Фондом свободного программного обеспечения;
# либо версии 3 лицензии, либо (по вашему выбору) любой более поздней версии.

# Эта программа распространяется в надежде, что она будет полезной,
# но БЕЗ КАКИХ-ЛИБО ГАРАНТИЙ; даже без подразумеваемой гарантии ТОВАРНОГО ВИДА
# или ПРИГОДНОСТИ ДЛЯ ОПРЕДЕЛЕННЫХ ЦЕЛЕЙ. Подробнее см. в Стандартной общественной лицензии GNU.

# Вы должны были получить копию Стандартной общественной лицензии GNU
# вместе с этой программой. Если это не так, см. <http://www.gnu.org/licenses/>.
#######################################################################

usage() {
cat <<EOF

  $0
  Copyright BTACTIC, SCCL
  Лицензировано под GNU PUBLIC LICENSE 3.0

  Использование: $0 --product-version=ВЕРСИЯ_ПРОДУКТА --build-number=НОМЕР_СБОРКИ --unlimited-organization=ОРГАНИЗАЦИЯ --tag-suffix=СУФФИКС_ТЕГА --debian-package-suffix=СУФФИКС_DEBIAN_ПАКЕТА
  Пример: $0 --product-version=7.4.1 --build-number=36 --unlimited-organization=btactic-oo --tag-suffix=-btactic --debian-package-suffix=-btactic

  Для Github actions вы можете захотеть собрать только бинарные файлы или только deb пакет, чтобы было проще очищать контейнеры
  Пример: $0 --product-version=7.4.1 --build-number=36 --unlimited-organization=btactic-oo --tag-suffix=-btactic --debian-package-suffix=-btactic --binaries-only
  Пример: $0 --product-version=7.4.1 --build-number=36 --unlimited-organization=btactic-oo --tag-suffix=-btactic --debian-package-suffix=-btactic --deb-only

EOF

}

BINARIES_ONLY="false"
DEB_ONLY="false"

UPSTREAM_ORGANIZATION="ONLYOFFICE"

SERVER_CUSTOM_COMMITS="81db34dee17f8a6a364669232a8c7c2f5d36d81f"
WEB_APPS_CUSTOM_COMMITS="140ef6d1d687532dcb03b05912838b8b4cf161a3"

# Проверить аргументы.
for option in "$@"; do
  case "$option" in
    -h | --help)
      usage
      exit 0
    ;;
    --product-version=*)
      PRODUCT_VERSION=`echo "$option" | sed 's/--product-version=//'`                 #!!!!!!!!!!!! --product-version=9.0.4
    ;;
    --build-number=*)
      BUILD_NUMBER=`echo "$option" | sed 's/--build-number=//'`
    ;;
    --unlimited-organization=*)
      UNLIMITED_ORGANIZATION=`echo "$option" | sed 's/--unlimited-organization=//'`   #!!!!!!!!!!!  btactic-oo  artrades
    ;;
    --tag-suffix=*)
      TAG_SUFFIX=`echo "$option" | sed 's/--tag-suffix=//'`
    ;;
    --debian-package-suffix=*)
      DEBIAN_PACKAGE_SUFFIX=`echo "$option" | sed 's/--debian-package-suffix=//'`
    ;;
    --binaries-only)
      BINARIES_ONLY="true"
    ;;
    --deb-only)
      DEB_ONLY="true"
    ;;
  esac
done

BUILD_BINARIES="true"
BUILD_DEB="true"

# Проверить, запущен ли скрипт с правами root
if [ "$EUID" -ne 0 ]
  then echo "Пожалуйста, запустите с правами root"
  exit 1
fi

if [ ${BINARIES_ONLY} == "true" ] ; then
  BUILD_BINARIES="true"
  BUILD_DEB="false"
fi

if [ ${DEB_ONLY} == "true" ] ; then
  BUILD_BINARIES="false"
  BUILD_DEB="true"
fi

# Проверить обязательные параметры
if [ "x${PRODUCT_VERSION}" == "x" ] ; then
    cat << EOF
    Необходимо указать опцию --product-version.
    Прерывание...
EOF
    usage
    exit 1
fi

if [ "x${BUILD_NUMBER}" == "x" ] ; then
    cat << EOF
    Необходимо указать опцию --build-number.
    Прерывание...
EOF
    usage
    exit 1
fi

if [ "x${UNLIMITED_ORGANIZATION}" == "x" ] ; then
    cat << EOF
    Необходимо указать опцию --unlimited-organization.
    Прерывание...
EOF
    usage
    exit 1
fi

if [ "x${TAG_SUFFIX}" == "x" ] ; then
    cat << EOF
    Необходимо указать опцию --tag-suffix.
    Прерывание...
EOF
    usage
    exit 1
fi

if [ "x${DEBIAN_PACKAGE_SUFFIX}" == "x" ] ; then
    cat << EOF
    Необходимо указать опцию --debian-package-suffix.
    Прерывание...
EOF
    usage
    exit 1
fi

# Обработка опции очистки docker контейнеров
PRUNE_DOCKER_CONTAINERS_ACTION="false"
if [ "x${PRUNE_DOCKER_CONTAINERS}" != "x" ] ; then
  if [ ${PRUNE_DOCKER_CONTAINERS} == "true" ] -o [ ${PRUNE_DOCKER_CONTAINERS} == "TRUE" ] ; then
    PRUNE_DOCKER_CONTAINERS_ACTION="true"
    cat << EOF
    ВНИМАНИЕ !
    ВНИМАНИЕ !
    --prune-docker-containers установлен в true
    Это приведет к удалению всех ваших docker контейнеров
    после сборки бинарных файлов.

    Ожидание 30 секунд для возможности нажать CTRL+C
EOF
    sleep 30s
  fi
fi

prepare_custom_repo() {

  _REPO=$1
  shift
  _TAG=$1
  shift
  _UNLIMITED_ORGANIZATION=$1
  shift
  # Остальные аргументы - коммиты для cherry-pick в порядке применения

  git clone https://github.com/${_UNLIMITED_ORGANIZATION}/${_REPO}
  cd ${_REPO}
  git remote add upstream-origin https://github.com/${UPSTREAM_ORGANIZATION}/${_REPO}

  git checkout master
  git pull upstream-origin master
  git fetch --all --tags
  git checkout tags/${_TAG} -b ${_TAG}-custom

  # Жестко задать временные user.name и user.email git для этого локального cherry-picked коммита
  git config user.name 'CherryPick User'
  git config user.email 'cherrypick@btacticoo.com'

  while [ "$#" -gt 0 ]; do
    _ncommit=$1
    if ! git cherry-pick "${_ncommit}"; then
      echo "Ошибка: cherry-pick коммита ${_ncommit} не удался в ${_REPO}" >&2
      echo "Прерывание!"
      exit 3
    fi
    shift
  done

  # Принудительно применить наши изменения
  git tag --delete ${_TAG}
  git tag -a "${_TAG}" -m "${_TAG}"

  cd ..

}

build_oo_binaries() {

  _OUT_FOLDER=$1 # out
  _PRODUCT_VERSION=$2 # 7.4.1
  _BUILD_NUMBER=$3 # 36
  _TAG_SUFFIX=$4 # -btactic
  _UNLIMITED_ORGANIZATION=$5 # btactic-oo

  _UPSTREAM_TAG="v${_PRODUCT_VERSION}.${_BUILD_NUMBER}"
  _UNLIMITED_ORGANIZATION_TAG="${_UPSTREAM_TAG}${_TAG_SUFFIX}"

  prepare_custom_repo "server" "${_UPSTREAM_TAG}" "${_UNLIMITED_ORGANIZATION}" ${SERVER_CUSTOM_COMMITS}
  prepare_custom_repo "web-apps" "${_UPSTREAM_TAG}" "${_UNLIMITED_ORGANIZATION}" ${WEB_APPS_CUSTOM_COMMITS}

  git clone \
    --depth=1 \
    --recursive \
    --branch ${_UPSTREAM_TAG} \
    https://github.com/${UPSTREAM_ORGANIZATION}/build_tools.git \
    build_tools
  # Игнорировать предупреждение о detached head
  cd build_tools
  mkdir ${_OUT_FOLDER}
  docker build --tag onlyoffice-document-editors-builder .
  docker run -e PRODUCT_VERSION=${_PRODUCT_VERSION} -e BUILD_NUMBER=${_BUILD_NUMBER} -e NODE_ENV='production' -v $(pwd)/${_OUT_FOLDER}:/build_tools/out -v $(pwd)/../server:/server -v $(pwd)/../web-apps:/web-apps onlyoffice-document-editors-builder /bin/bash -c '\
    cd tools/linux && \
    python3 ./automate.py --branch=tags/'"${_UPSTREAM_TAG}"
  cd ..

}

if [ "${BUILD_BINARIES}" == "true" ] ; then
  build_oo_binaries "out" "${PRODUCT_VERSION}" "${BUILD_NUMBER}" "${TAG_SUFFIX}" "${UNLIMITED_ORGANIZATION}"
  build_oo_binaries_exit_value=$?
fi

# Сымитировать, что сборка бинарных файлов прошла успешно
# когда мы хотим только собрать deb пакет
if [ ${DEB_ONLY} == "true" ] ; then
  build_oo_binaries_exit_value=0
fi

if [ "${BUILD_DEB}" == "true" ] ; then
  if [ ${build_oo_binaries_exit_value} -eq 0 ] ; then
    cd deb_build
    docker build --tag onlyoffice-deb-builder . -f Dockerfile-manual-debian-11
    docker run \
      --env PRODUCT_VERSION=${PRODUCT_VERSION} \
      --env BUILD_NUMBER=${BUILD_NUMBER} \
      --env TAG_SUFFIX=${TAG_SUFFIX} \
      --env UNLIMITED_ORGANIZATION=${UNLIMITED_ORGANIZATION} \
      --env DEBIAN_PACKAGE_SUFFIX=${DEBIAN_PACKAGE_SUFFIX} \
      -v $(pwd):/usr/local/unlimited-onlyoffice-package-builder:ro \
      -v $(pwd):/root:rw \
      -v $(pwd)/../build_tools:/root/build_tools:ro \
      onlyoffice-deb-builder /bin/bash -c "/usr/local/unlimited-onlyoffice-package-builder/onlyoffice-deb-builder.sh --product-version ${PRODUCT_VERSION} --build-number ${BUILD_NUMBER} --tag-suffix ${TAG_SUFFIX} --unlimited-organization ${UNLIMITED_ORGANIZATION} --debian-package-suffix ${DEBIAN_PACKAGE_SUFFIX}" \
      2>&1 | ts '[%Y-%m-%d %H:%M:%S]' | tee build_with_timestamps.log
    cd ..
  else
    echo "Сборка бинарных файлов не удалась!"
    echo "Прерывание... !"
    exit 1
  fi
fi
