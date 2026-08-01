# Taskify Space — Flutter

Aplicativo Flutter que consome a API do projeto irmão `../backend-java`.

## Pré-requisitos

- Flutter estável compatível com o SDK declarado em `pubspec.yaml`;
- Android Emulator para a primeira plataforma de validação;
- PostgreSQL e `backend-java` executando na porta `8080`.

## Instalação

```powershell
flutter pub get
```

## Executar no Android Emulator

Inicie o backend e, a partir desta pasta, execute:

```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

A configuração `Flutter (Pixel 7)` em `.vscode/launch.json` já usa essa URL.
`10.0.2.2` é o endereço pelo qual o Android Emulator alcança o host.

Para outros alvos, informe uma única `API_BASE_URL`:

| Alvo | URL local típica |
| --- | --- |
| Android Emulator | `http://10.0.2.2:8080` |
| Android físico | `http://<IP-LAN-DO-HOST>:8080` (exige liberar esse host em um flavor de desenvolvimento) |
| Web, desktop e iOS Simulator | `http://localhost:8080` |

Em produção, `API_BASE_URL` deve usar HTTPS. A URL não é segredo, mas senhas,
access tokens, refresh tokens e chaves nunca devem ser passados por
`--dart-define`.

## Login

A primeira tela chama `POST /auth/login` com `username` (o e-mail) e
`password`. O aplicativo gera um UUID aleatório persistente por instalação e o
envia em `X-Device-Id`. Em caso de sucesso, access token e refresh token são
armazenados juntos no armazenamento seguro, sem serem exibidos ou registrados.

O Android permite HTTP apenas no build `debug` e somente para os hosts locais
de desenvolvimento configurados. Nesta primeira entrega, a allowlist contém
somente `10.0.2.2`, para o Android Emulator. O manifest principal contém a
permissão de Internet para que builds de release possam acessar uma API HTTPS.
O backup automático do Android fica desativado para impedir a restauração de
dados cifrados sem a chave correspondente do dispositivo.

## Verificações

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```
