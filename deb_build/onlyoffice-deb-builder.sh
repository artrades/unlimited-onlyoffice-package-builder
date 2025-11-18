#!/bin/bash

#######################################################################
# Сборщик Deb пакетов OnlyOffice

# Copyright (C) 2024 BTACTIC, SCCL

# Эта программа является свободным программным обеспечением: вы можете 
# распространять и/или модифицировать её на условиях Стандартной 
# общественной лицензии GNU в том виде, в каком она была опубликована 
# Фондом свободного программного обеспечения; либо версии 3 лицензии, 
# либо (по вашему выбору) любой более поздней версии.

# Эта программа распространяется в надежде, что она будет полезной,
# но БЕЗ КАКИХ-ЛИБО ГАРАНТИЙ; даже без подразумеваемой гарантии ТОВАРНОГО
# ВИДА или ПРИГОДНОСТИ ДЛЯ ОПРЕДЕЛЕННЫХ ЦЕЛЕЙ. Подробнее см. в Стандартной
# общественной лицензии GNU.

# Вы должны были получить копию Стандартной общественной лицензии GNU
# вместе с этой программой. 
# Если это не так, см. <http://www.gnu.org/licenses/>.
#######################################################################

usage() {
cat <<EOF

  $0
  Copyright BTACTIC, SCCL
  Лицензировано под GNU PUBLIC LICENSE 3.0

  Использование: $0 --product-version=ВЕРСИЯ_ПРОДУКТА --build-number=НОМЕР_СБОРКИ --unlimited-organization=ОРГАНИЗАЦИЯ --tag-suffix=СУФФИКС_ТЕГА --debian-package-suffix=СУФФИКС_DEBIAN_ПАКЕТА
  Пример: $0 --product-version=7.4.1 --build-number=36 --unlimited-organization=btactic-oo --tag-suffix=-btactic --debian-package-suffix=-btactic

EOF

}


# Проверить аргументы.
for option in "$@"; do
  case "$option" in
    -h | --help)
      usage
      exit 0
    ;;
    --product-version=*)
      PRODUCT_VERSION=`echo "$option" | sed 's/--product-version=//'`
    ;;
    --build-number=*)
      BUILD_NUMBER=`echo "$option" | sed 's/--build-number=//'`
    ;;
    --unlimited-organization=*)
      UNLIMITED_ORGANIZATION=`echo "$option" | sed 's/--unlimited-organization=//'`
    ;;
    --tag-suffix=*)
      TAG_SUFFIX=`echo "$option" | sed 's/--tag-suffix=//'`
    ;;
    --debian-package-suffix=*)
      DEBIAN_PACKAGE_SUFFIX=`echo "$option" | sed 's/--debian-package-suffix=//'`
    ;;
  esac
done


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

build_deb "${PRODUCT_VERSION}" "${BUILD_NUMBER}" "${TAG_SUFFIX}" "${UNLIMITED_ORGANIZATION}" "${DEBIAN_PACKAGE_SUFFIX}"
