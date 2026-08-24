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

O modo **Criar conta** chama `POST /users`. O retorno `201 Created` confirma o
cadastro, mas não cria uma sessão: o aplicativo volta ao login, mantém o e-mail
preenchido e orienta o usuário a confirmar o cadastro pelo link recebido antes
de entrar.

Depois que a sessão é armazenada, o aplicativo chama `GET /spaces` com o access
token no cabeçalho `Authorization: Bearer <token>` e apresenta a primeira página
de espaços. Campos de participação ausentes na resposta são tratados como
opcionais.

Nas telas autenticadas, o botão **Sair** chama `POST /auth/logout` enviando
somente o `refreshToken`. Depois da tentativa de revogação, o aplicativo remove
access token e refresh token do armazenamento local e da memória, fecha as
telas protegidas e retorna ao login. A limpeza local também acontece se a API
estiver temporariamente indisponível.

A listagem permite combinar a busca parcial por `name` com os filtros
`spaceUserRole` e `spaceMembershipStatus`. A interface oferece somente os status
`PENDING` e `APPROVED`, que são os estados admitidos pela regra-base dessa
listagem. As consultas são ordenadas por `id`, e uma barra no fim da lista
permite navegar pelas páginas e escolher 5, 10, 20 ou 50 registros por página.
Ao alterar essa quantidade, aplicar ou limpar filtros, a consulta reinicia na
página zero.

Em espaços com participação aprovada, o chip com a quantidade de participantes
abre uma tela própria por meio de `GET /spaces/{spaceId}/participants`. A lista
exibe nome, papel, categorias consideradas e pontuação, com paginação e filtros
opcionais por `name`, `spaceUserRole` e `taskCategories`. Também é possível
ordenar por identificador, nome, papel ou pontuação; por padrão, o aplicativo
solicita a maior pontuação primeiro com `sort=score,desc`. Em caso de empate, o
backend usa o identificador crescente. As categorias selecionadas determinam
quais execuções compõem a pontuação e não removem participantes sem execução
nelas.

O botão **Ver participações**, exibido ao lado de **Ver tarefas**, abre a
listagem paginada de `GET /spaces/{spaceId}/participations`. A tela mostra nome,
papel e situação de cada vínculo e permite filtrar opcionalmente por `username`
e por um ou mais valores de `statuses`. Sem esses filtros, todas as participações
do espaço são consultadas; as páginas usam ordenação estável por identificador.

Administradores e gerentes podem editar participações pelo ícone de lápis.
A atualização usa `PATCH /spaces/{spaceId}/participations/{membershipId}` e
envia somente os campos alterados em `status` e `spaceUserRole`. Administradores
podem alterar papel e situação; conforme a autorização do backend, gerentes
alteram apenas a situação de vínculos com papel de participante.

Nos espaços em que o usuário ainda não possui vínculo, o botão **Solicitar
participação** chama `POST /spaces/{spaceId}/participations/request`, sem corpo.
Após o sucesso `204 No Content`, a página é atualizada e passa a exibir a
participação como pendente.

O botão **Novo espaço** chama `POST /spaces` com o mesmo access token e envia
somente o campo `name`, normalizado e validado com o limite de 255 caracteres.
O backend cria esse espaço como inativo e registra o usuário autenticado como
administrador. Como `GET /spaces` lista somente espaços ativos, a interface
confirma a criação sem inserir o novo espaço na listagem atual; ele só poderá
aparecer depois de ser ativado.

Em espaços nos quais a participação aprovada é de administrador ou gerente, o
ícone de lápis abre a edição por meio de `PUT /spaces/{spaceId}`. Administradores
podem alterar `name` e `available`; gerentes podem alterar `name`, enquanto a
disponibilidade permanece somente para leitura conforme a autorização do
backend. Depois do retorno `200 OK`, a página atual da listagem é consultada
novamente para refletir os dados confirmados pelo servidor.

Em espaços com participação aprovada, o botão **Ver tarefas** abre uma listagem
que chama `GET /spaces/{spaceId}/tasks` com `page`, `size` e `sort=id,asc`. O
espaço é definido pelo caminho para que `totalElements` e `totalPages` representem
somente as tarefas daquele espaço. A tela também permite combinar, por meio do
Specification, descrição parcial, situação, categorias e pontuação exata,
mínima ou máxima. Aplicar ou limpar filtros e trocar a quantidade de registros
reinicia a consulta na página zero; a barra inferior permite navegar pelas
páginas e escolher 5, 10, 20 ou 50 registros.

O ícone à esquerda de cada tarefa ativa abre a confirmação de execução.
O diálogo inicia com a data e a hora atuais e com o usuário autenticado entre
os executores. Como o backend sempre inclui esse usuário, ele permanece fixo;
a data, o horário e os demais executores podem ser alterados. A busca do
multiselect usa `GET /spaces/{spaceId}/participants/search?name=...`. Confirmar
envia `POST /spaces/{spaceId}/tasks/{taskId}` com `executionDate` no formato
`yyyy-MM-dd-HH-mm` e, quando houver executores adicionais, seus identificadores
em `usersIds`. Sem adicionais, `usersIds` é omitido.

Ao tocar no nome de uma tarefa, o aplicativo abre seu histórico por meio de
`GET /spaces/{spaceId}/tasks/{taskId}/executions`, com `page` e `size`. A lista
vem ordenada das execuções mais recentes para as mais antigas e mostra a data,
a hora e a pontuação de cada execução; os nomes dos executores ficam ocultos
até o usuário tocar no ícone de participantes do respectivo item.

Administradores e gerentes criam tarefas por meio de
`POST /spaces/{spaceId}/tasks`. O identificador do espaço é enviado no caminho
e também no corpo, conforme o contrato atual do DTO de criação.

Administradores e gerentes do espaço podem editar cada tarefa pelo botão de
lápis. O formulário atualiza descrição, pontuação, categoria e agenda por meio
de `PUT /spaces/{spaceId}/tasks/{taskId}`. A agenda atual é sempre reenviada para
preservá-la; ela só é removida quando a opção de agenda é desligada explicitamente.
Situação e criador são somente leitura nesse endpoint.

O ícone de visibilidade no chip de situação permite que administradores e
gerentes ativem ou desativem a tarefa por meio de
`PATCH /spaces/{spaceId}/tasks/{taskId}`, sem corpo na requisição. A operação
considera somente `204 No Content` como sucesso e, em seguida, recarrega a
página e os filtros atuais para refletir o novo estado retornado pela API.

O Android permite HTTP apenas no build `debug` e somente para os hosts locais
de desenvolvimento configurados. A allowlist contém `localhost` e `10.0.2.2`,
o alias usado pelo Android Emulator. O manifest principal contém a
permissão de Internet para que builds de release possam acessar uma API HTTPS.
O backup automático do Android fica desativado para impedir a restauração de
dados cifrados sem a chave correspondente do dispositivo.

## Verificações

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

## Recuperação de senha e códigos

Ao solicitar a recuperação, o aplicativo chama `POST /auth/recovery-token` com
`{"address":"usuario@exemplo.com"}`. O `200 OK` é uma confirmação genérica e
não devolve o código: se a conta existir, ele será enviado por e-mail.

Depois do `200`, a tela de redefinição solicita o código, a nova senha e sua
confirmação. O código tem exatamente seis dígitos ASCII, pode começar com zero
e, na configuração padrão do backend, expira em 10 minutos. O envio chama
`POST /auth/new-password/{codigo}` com `newPassword` e
`newPasswordConfirmation`; o sucesso é `204 No Content`.

O e-mail também traz um link como alternativa à digitação manual. Esse link
abre `/new-password/{codigo}` sem exigir sessão e preenche o mesmo fluxo de
redefinição. Depois do sucesso, qualquer sessão local é removida e a pilha de
navegação volta ao login com a confirmação da troca.

O backend monta o link concatenando o código ao valor de `PASSWORD_RECOVER_URI`.
Esse valor precisa terminar com `/` e apontar para a entrada adequada ao alvo:

- Web: `PASSWORD_RECOVER_URI=https://app.exemplo.com/new-password/`. O servidor
  que hospeda o Flutter Web precisa reescrever acessos diretos a
  `/new-password/*` para `index.html`; o aplicativo usa URLs sem `#`.
- Android/iOS com esquema customizado:
  `PASSWORD_RECOVER_URI=taskifyspace://new-password/`.

O manifest Android registra `http` e `https` somente para os hosts locais
`localhost` e `10.0.2.2`, no prefixo `/new-password/`, além do esquema
`taskifyspace`. Ele não reivindica links de outros domínios. No iOS, por falta de
um domínio de produção definido, apenas o esquema customizado está registrado.

O esquema customizado não comprova a identidade do aplicativo. Para links
verificados em produção, é necessário escolher o domínio final, adicioná-lo ao
manifest/entitlements e publicar `assetlinks.json` no Android e o arquivo AASA
(`apple-app-site-association`) no iOS. Um único link HTTPS verificado pode então
abrir o aplicativo instalado e manter a página web como fallback.
