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

  Дополнительные опции:
  --binaries-only    - собрать только бинарные файлы
  --deb-only         - собрать только DEB пакет (предполагает, что бинарные файлы уже собраны)
  --skip-download    - пропустить скачивание исходных кодов (предполагает, что репозитории уже скачаны)

  Примеры комбинированного использования:
  # Собрать всё, но пропустить скачивание
  $0 --product-version=7.4.1 --build-number=36 --unlimited-organization=btactic-oo --tag-suffix=-btactic --debian-package-suffix=-btactic --skip-download

  # Собрать только DEB пакет, пропуская скачивание и сборку бинарных файлов
  $0 --product-version=7.4.1 --build-number=36 --unlimited-organization=btactic-oo --tag-suffix=-btactic --debian-package-suffix=-btactic --deb-only --skip-download

  Для Github actions вы можете захотеть собрать только бинарные файлы или только deb пакет, чтобы было проще очищать контейнеры
  Пример: $0 --product-version=7.4.1 --build-number=36 --unlimited-organization=btactic-oo --tag-suffix=-btactic --debian-package-suffix=-btactic --binaries-only
  Пример: $0 --product-version=7.4.1 --build-number=36 --unlimited-organization=btactic-oo --tag-suffix=-btactic --debian-package-suffix=-btactic --deb-only

# Записывает и сессию и вывод с временными метками
script -q -c \
  "sudo ./onlyoffice-package-builder.sh \
    --product-version=9.0.4 \
    --build-number=52 \
    --unlimited-organization=btactic-oo \
    --tag-suffix=-btactic \
    --debian-package-suffix=-btactic \
    -binaries-only \
    2>&1 | ts '[%Y-%m-%d %H:%M:%S]' | tee build_with_timestamps_.log" \
  build_session.log


EOF

}

BINARIES_ONLY="false"
DEB_ONLY="false"
SKIP_DOWNLOAD="false"

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
    --skip-download)
      SKIP_DOWNLOAD="true"
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

  if [ "${SKIP_DOWNLOAD}" == "false" ]; then
    echo "=== ПОДГОТОВКА: Настройка кастомных репозиториев ==="
    echo "Текущая директория: $(pwd)"
    echo "Будет выполнена команда:"
    echo "prepare_custom_repo \"server\" \"${_UPSTREAM_TAG}\" \"${_UNLIMITED_ORGANIZATION}\" ${SERVER_CUSTOM_COMMITS}"
    echo ""
    
    read -p "Продолжить выполнение? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
      echo "Прерывание выполнения..."
      exit 1
    fi
    
    prepare_custom_repo "server" "${_UPSTREAM_TAG}" "${_UNLIMITED_ORGANIZATION}" ${SERVER_CUSTOM_COMMITS}

    echo "=== ПОДГОТОВКА: Настройка web-apps репозитория ==="
    echo "Текущая директория: $(pwd)"
    echo "Будет выполнена команда:"
    echo "prepare_custom_repo \"web-apps\" \"${_UPSTREAM_TAG}\" \"${_UNLIMITED_ORGANIZATION}\" ${WEB_APPS_CUSTOM_COMMITS}"
    echo ""
    
    read -p "Продолжить выполнение? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
      echo "Прерывание выполнения..."
      exit 1
    fi
    
    prepare_custom_repo "web-apps" "${_UPSTREAM_TAG}" "${_UNLIMITED_ORGANIZATION}" ${WEB_APPS_CUSTOM_COMMITS}

    echo "=== ЭТАП 1: Клонирование build_tools ==="
    echo "Текущая директория: $(pwd)"
    echo "Будет выполнена команда:"
    echo "git clone --depth=1 --recursive --branch ${_UPSTREAM_TAG} \\"
    echo "  https://github.com/${UPSTREAM_ORGANIZATION}/build_tools.git \\"
    echo "  build_tools"
    echo ""
    
    read -p "Продолжить выполнение? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
      echo "Прерывание выполнения..."
      exit 1
    fi
    
    git clone \
      --depth=1 \
      --recursive \
      --branch ${_UPSTREAM_TAG} \
      https://github.com/${UPSTREAM_ORGANIZATION}/build_tools.git \
      build_tools
  else
    echo "=== ПРОПУСК СКАЧИВАНИЯ ==="
    echo "Режим --skip-download: пропускаем скачивание репозиториев"
    echo "Предполагается, что репозитории уже существуют в текущей директории:"
    echo "  - server/"
    echo "  - web-apps/" 
    echo "  - build_tools/"
    echo ""
    
    # Проверяем существование необходимых директорий
    if [ ! -d "server" ] || [ ! -d "web-apps" ] || [ ! -d "build_tools" ]; then
      echo "ОШИБКА: Не найдены необходимые репозитории!"
      echo "В режиме --skip-download должны существовать:"
      echo "  server/, web-apps/, build_tools/"
      echo "Прерывание выполнения..."
      exit 1
    fi
    
    read -p "Репозитории найдены. Продолжить сборку? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
      echo "Прерывание выполнения..."
      exit 1
    fi
  fi

  echo "=== ЭТАП 2: Переход в build_tools и создание выходной директории ==="
  echo "Текущая директория: $(pwd)"
  echo "Переход в: build_tools"
  cd build_tools
  echo "Текущая директория после перехода: $(pwd)"
  
  echo "Создание выходной директории: ${_OUT_FOLDER}"
  mkdir ${_OUT_FOLDER}
  echo "Создана директория: $(pwd)/${_OUT_FOLDER}"
  echo ""

  echo "=== ЭТАП 3: Сборка Docker образа ==="
  echo "Текущая директория: $(pwd)"
  echo "Будет выполнена команда:"
  echo "docker build --tag onlyoffice-document-editors-builder ."
  echo ""
  
  read -p "Продолжить выполнение? (y/N): " confirm
  if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Прерывание выполнения..."
    exit 1
  fi
  
  docker build --tag onlyoffice-document-editors-builder .

  echo "=== ЭТАП 4: Запуск Docker контейнера для сборки ==="
  echo "Текущая директория: $(pwd)"
  echo "Будет выполнена команда:"
  echo "docker run \\"
  echo "  -e PRODUCT_VERSION=${_PRODUCT_VERSION} \\"
  echo "  -e BUILD_NUMBER=${_BUILD_NUMBER} \\"
  echo "  -e NODE_ENV='production' \\"
  echo "  -v \$(pwd)/${_OUT_FOLDER}:/build_tools/out \\"
  echo "  -v \$(pwd)/../server:/server \\"
  echo "  -v \$(pwd)/../web-apps:/web-apps \\"
  echo "  onlyoffice-document-editors-builder \\"
  echo "  /bin/bash -c 'cd tools/linux && python3 ./automate.py --branch=tags/\"${_UPSTREAM_TAG}\"'"
  echo ""
  
  read -p "В ЭТОТ МОМЕНТ МОЖНО ПАТЧИТЬ automate.py Запустить сборку в Docker контейнере? (y/N): " confirm
  if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Прерывание выполнения..."
    exit 1
  fi
  
  docker run \
    -e PRODUCT_VERSION=${_PRODUCT_VERSION} \
    -e BUILD_NUMBER=${_BUILD_NUMBER} \
    -e NODE_ENV='production' \
    -v $(pwd)/${_OUT_FOLDER}:/build_tools/out \
    -v $(pwd)/../server:/server \
    -v $(pwd)/../web-apps:/web-apps \
    onlyoffice-document-editors-builder \
    /bin/bash -c '\
      cd tools/linux && \
      python3 ./automate.py --branch=tags/'"${_UPSTREAM_TAG}"

  echo "=== ЭТАП 5: Возврат в исходную директорию ==="
  echo "Текущая директория: $(pwd)"
  echo "Возврат на уровень выше"
  cd ..
  echo "Текущая директория после возврата: $(pwd)"
  echo ""

  echo "=== Сборка бинарных файлов завершена успешно! ==="
  echo "Результаты сборки находятся в: $(pwd)/build_tools/${_OUT_FOLDER}"
  echo "Параметры сборки:"
  echo "  Версия продукта: ${_PRODUCT_VERSION}"
  echo "  Номер сборки: ${_BUILD_NUMBER}"
  echo "  Тег upstream: ${_UPSTREAM_TAG}"
  echo "  Организация: ${_UNLIMITED_ORGANIZATION}"
  echo "  Выходная папка: ${_OUT_FOLDER}"
}

build_deb() {

  build_deb_pre_pwd="$(pwd)"
  DOCUMENT_SERVER_PACKAGE_PATH="$(pwd)/document-server-package"

  _PRODUCT_VERSION=$1 # 7.4.1
  _BUILD_NUMBER=$2 # 36
  _TAG_SUFFIX=$3 # -btactic
  _UNLIMITED_ORGANIZATION=$4 # btactic-oo
  _DEBIAN_PACKAGE_SUFFIX=$5

  _GIT_CLONE_BRANCH="v${_PRODUCT_VERSION}.${_BUILD_NUMBER}"

  # TODO: Эти требования должны быть перенесены в Dockerfile
  # apt install build-essential m4 npm
  # npm install -g pkg

  echo "=== ЭТАП 1: Клонирование репозитория ==="
  echo "Текущая директория: $(pwd)"
  echo "Будет выполнена команда:"
  echo "git clone https://github.com/ONLYOFFICE/document-server-package.git -b ${_GIT_CLONE_BRANCH}"
  echo "Целевая директория: ${DOCUMENT_SERVER_PACKAGE_PATH}"
  echo ""
  
  read -p "Продолжить выполнение? (y/N): " confirm
  if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Прерывание выполнения..."
    exit 1
  fi
  
  git clone https://github.com/ONLYOFFICE/document-server-package.git -b ${_GIT_CLONE_BRANCH}

  echo "=== ЭТАП 2: Настройка Makefile ==="
  echo "Текущая директория: $(pwd)"
  echo "Переход в: ${DOCUMENT_SERVER_PACKAGE_PATH}"
  cd ${DOCUMENT_SERVER_PACKAGE_PATH}
  echo "Текущая директория после перехода: $(pwd)"
  
  echo "Будет добавлено в Makefile:"
  echo "deb_dependencies: \$(DEB_DEPS)"
  echo ""
  
  read -p "Продолжить выполнение? (y/N): " confirm
  if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Прерывание выполнения..."
    exit 1
  fi
  
  cat << EOF >> Makefile

deb_dependencies: \$(DEB_DEPS)

EOF

  echo "=== ПРОВЕРКА: Отображение изменений в Makefile ==="
  echo "Последние 5 строк Makefile:"
  tail -5 Makefile
  echo ""
  
  read -p "Изменения применены. Продолжить? (y/N): " confirm
  if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Прерывание выполнения..."
    exit 1
  fi

  echo "=== ЭТАП 3: Установка зависимостей через make ==="
  echo "Текущая директория: $(pwd)"
  echo "Будет выполнена команда:"
  echo "PRODUCT_VERSION=\"${_PRODUCT_VERSION}\" BUILD_NUMBER=\"${_BUILD_NUMBER}${_DEBIAN_PACKAGE_SUFFIX}\" make deb_dependencies"
  echo ""
  
  read -p "Продолжить выполнение? (y/N): " confirm
  if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Прерывание выполнения..."
    exit 1
  fi
  
  PRODUCT_VERSION="${_PRODUCT_VERSION}" BUILD_NUMBER="${_BUILD_NUMBER}${_DEBIAN_PACKAGE_SUFFIX}" make deb_dependencies

  echo "=== ЭТАП 4: Установка build-зависимостей ==="
  echo "Текущая директория: $(pwd)"
  echo "Переход в: ${DOCUMENT_SERVER_PACKAGE_PATH}/deb/build"
  cd ${DOCUMENT_SERVER_PACKAGE_PATH}/deb/build
  echo "Текущая директория после перехода: $(pwd)"
  
  echo "Будет выполнена команда:"
  echo "apt-get -qq build-dep -y ./"
  echo ""
  
  read -p "Продолжить выполнение? (y/N): " confirm
  if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Прерывание выполнения..."
    exit 1
  fi
  
  apt-get -qq build-dep -y ./

  echo "=== ЭТАП 5: Сборка DEB пакета ==="
  echo "Текущая директория: $(pwd)"
  echo "Переход в: ${DOCUMENT_SERVER_PACKAGE_PATH}"
  cd ${DOCUMENT_SERVER_PACKAGE_PATH}
  echo "Текущая директория после перехода: $(pwd)"
  
  echo "Будет выполнена команда:"
  echo "PRODUCT_VERSION=\"${_PRODUCT_VERSION}\" BUILD_NUMBER=\"${_BUILD_NUMBER}${_DEBIAN_PACKAGE_SUFFIX}\" make deb"
  echo ""
  
  read -p "Начать финальную сборку DEB пакета? (y/N): " confirm
  if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Прерывание выполнения..."
    exit 1
  fi
  
  PRODUCT_VERSION="${_PRODUCT_VERSION}" BUILD_NUMBER="${_BUILD_NUMBER}${_DEBIAN_PACKAGE_SUFFIX}" make deb

  echo "=== ЭТАП 6: Возврат в исходную директорию ==="
  echo "Текущая директория: $(pwd)"
  echo "Возврат в исходную директорию: ${build_deb_pre_pwd}"
  cd ${build_deb_pre_pwd}
  echo "Текущая директория после возврата: $(pwd)"
  echo ""

  echo "=== Сборка завершена успешно! ==="
  echo "DEB пакет должен быть создан в директории: ${DOCUMENT_SERVER_PACKAGE_PATH}"
  echo "Параметры сборки:"
  echo "  Версия продукта: ${_PRODUCT_VERSION}"
  echo "  Номер сборки: ${_BUILD_NUMBER}"
  echo "  Суффикс пакета: ${_DEBIAN_PACKAGE_SUFFIX}"
  echo "  Полная версия: ${_PRODUCT_VERSION}.${_BUILD_NUMBER}${_DEBIAN_PACKAGE_SUFFIX}"
}

# Основной процесс сборки
echo "=== НАЧАЛО ПРОЦЕССА СБОРКИ ==="
echo "Параметры сборки:"
echo "  Версия продукта: ${PRODUCT_VERSION}"
echo "  Номер сборки: ${BUILD_NUMBER}"
echo "  Организация: ${UNLIMITED_ORGANIZATION}"
echo "  Суффикс тега: ${TAG_SUFFIX}"
echo "  Суффикс DEB пакета: ${DEBIAN_PACKAGE_SUFFIX}"
echo "  Режим только бинарные: ${BINARIES_ONLY}"
echo "  Режим только DEB: ${DEB_ONLY}"
echo "  Пропуск скачивания: ${SKIP_DOWNLOAD}"
echo ""

if [ "${BUILD_BINARIES}" == "true" ] ; then
  echo "=== НАЧАЛО СБОРКИ БИНАРНЫХ ФАЙЛОВ ==="
  echo "Текущая директория: $(pwd)"
  echo "Будет выполнена функция: build_oo_binaries"
  echo "Параметры:"
  echo "  Выходная папка: out"
  echo "  Версия продукта: ${PRODUCT_VERSION}"
  echo "  Номер сборки: ${BUILD_NUMBER}"
  echo "  Суффикс тега: ${TAG_SUFFIX}"
  echo "  Организация: ${UNLIMITED_ORGANIZATION}"
  echo ""
  
  read -p "Начать сборку бинарных файлов? (y/N): " confirm
  if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Прерывание выполнения..."
    exit 1
  fi
  
  build_oo_binaries "out" "${PRODUCT_VERSION}" "${BUILD_NUMBER}" "${TAG_SUFFIX}" "${UNLIMITED_ORGANIZATION}"
  build_oo_binaries_exit_value=$?
fi

# Сымитировать, что сборка бинарных файлов прошла успешно
# когда мы хотим только собрать deb пакет
if [ ${DEB_ONLY} == "true" ] ; then
  echo "=== РЕЖИМ ТОЛЬКО DEB ПАКЕТ ==="
  echo "Пропускаем сборку бинарных файлов, используем существующие"
  echo ""
  
  read -p "Продолжить с сборкой DEB пакета? (y/N): " confirm
  if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Прерывание выполнения..."
    exit 1
  fi
  
  build_oo_binaries_exit_value=0
fi

if [ "${BUILD_DEB}" == "true" ] ; then
  echo "=== НАЧАЛО СБОРКИ DEB ПАКЕТА ==="
  echo "Текущая директория: $(pwd)"
  echo "Будет выполнено:"
  echo "  cd deb_build"
  echo "  docker build --tag onlyoffice-deb-builder . -f Dockerfile-manual-debian-11"
  echo "  docker run с монтированием:"
  echo "    - deb_build → /usr/local/unlimited-onlyoffice-package-builder (ro)"
  echo "    - deb_build → /root (rw)"
  echo "    - ../build_tools → /root/build_tools (ro)"
  echo "  Внутри контейнера: onlyoffice-deb-builder.sh"
  echo ""
  
  read -p "Начать сборку DEB пакета? (y/N): " confirm
  if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Прерывание выполнения..."
    exit 1
  fi
  
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

echo "=== ВСЕ ЭТАПЫ СБОРКИ ЗАВЕРШЕНЫ УСПЕШНО! ==="
