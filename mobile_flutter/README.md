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
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://localhost:8080
```

A configuração `Flutter (Pixel 7)` em `.vscode/launch.json` já usa essa URL.
`localhost` é o endereço pelo qual o Android Emulator alcança o host.

Para outros alvos, informe uma única `API_BASE_URL`:

| Alvo | URL local típica |
| --- | --- |
| Android Emulator | `http://localhost:8080` |
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

Depois que a sessão é armazenada, o aplicativo chama `GET /spaces` com o access
token no cabeçalho `Authorization: Bearer <token>` e apresenta a primeira página
de espaços. Campos de participação ausentes na resposta são tratados como
opcionais.

A listagem permite combinar a busca parcial por `name` com os filtros
`spaceUserRole` e `spaceMembershipStatus`. A interface oferece somente os status
`PENDING` e `APPROVED`, que são os estados admitidos pela regra-base dessa
listagem. As consultas são ordenadas por `id`, e uma barra no fim da lista
permite navegar pelas páginas e escolher 5, 10, 20 ou 50 registros por página.
Ao alterar essa quantidade, aplicar ou limpar filtros, a consulta reinicia na
página zero.

O botão **Novo espaço** chama `POST /spaces` com o mesmo access token e envia
somente o campo `name`, normalizado e validado com o limite de 255 caracteres.
O backend cria esse espaço como inativo e registra o usuário autenticado como
administrador. Como `GET /spaces` lista somente espaços ativos, a interface
confirma a criação sem inserir o novo espaço na listagem atual; ele só poderá
aparecer depois de ser ativado.

Em espaços com participação aprovada, o botão **Ver tarefas** abre uma listagem
que chama `GET /tasks` com `spaceId`, `page`, `size` e `sort=id,asc`. O filtro por
espaço é aplicado no backend para que `totalElements` e `totalPages` representem
somente as tarefas daquele espaço. A tela também permite combinar, por meio do
Specification, descrição parcial, situação, categorias e pontuação exata,
mínima ou máxima. Aplicar ou limpar filtros e trocar a quantidade de registros
reinicia a consulta na página zero; a barra inferior permite navegar pelas
páginas e escolher 5, 10, 20 ou 50 registros.

O Android permite HTTP apenas no build `debug` e somente para os hosts locais
de desenvolvimento configurados. Nesta primeira entrega, a allowlist contém
somente `localhost`, para o Android Emulator. O manifest principal contém a
permissão de Internet para que builds de release possam acessar uma API HTTPS.
O backup automático do Android fica desativado para impedir a restauração de
dados cifrados sem a chave correspondente do dispositivo.

## Verificações

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```
