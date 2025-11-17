# unlimited-onlyoffice-package-builder

Unlimited OnlyOffice Package Builder позволяет собирать OnlyOffice без ограничений и упаковывать его (в настоящее время поддерживаются только deb-пакеты).

## Требования

### Введение

Для упрощения сборки deb-пакетов OnlyOffice в этом методе сборки используется Docker. Здесь вы найдете инструкции по настройке пользователя для работы с Docker. Эту настройку нужно выполнить только один раз. Данные инструкции по Docker предназначены для Ubuntu 20.04, но инструкции по установке Docker для вашей ОС также подойдут.

Обратите внимание на дистрибутивы, основанные на RHEL 8. Найдите инструкцию по установке docker-ce. Попытка установить пакет docker напрямую приведет к установке *podman* и *buildah*, которые **работают не так же, как docker-ce**, несмотря на то, что они могут позиционироваться как эквивалентные решения.

### Настройка Docker

*Примечание: Команды для настройки Docker необходимо выполнять либо от имени пользователя root, либо от имени пользователя, входящего в группу sudo (обычно это административный пользователь).*

#### Установка необходимых компонентов для Docker

```
sudo apt-get update
sudo apt-get remove docker docker-engine docker.io
sudo apt-get install linux-image-extra-$(uname -r) linux-image-extra-virtual
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common
```
#### Настройка apt-репозитория Docker

```
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo tee /etc/apt/sources.list.d/docker.list <<EOM
deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable
EOM

sudo apt-get update
```

#### Установка Docker

```
sudo apt-get install docker-ce
```

## Пример сборки

```
mkdir ~/build-onlyoffice-test-01
cd ~/build-onlyoffice-test-01
git clone https://github.com/btactic-oo/unlimited-onlyoffice-package-builder
cd unlimited-onlyoffice-package-builder
./onlyoffice-package-builder.sh --product-version=8.0.1 --build-number=31 --unlimited-organization=btactic-oo --tag-suffix=-btactic --debian-package-suffix=-btactic
```
