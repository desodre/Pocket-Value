# Repository Guidelines

## Produto e escopo

PocketValue é um aplicativo Flutter para **Android e iOS**. Ele mostra cotações do Ibovespa e de ativos e índices internacionais em uma lista acompanhada pelo usuário. A tela inicial deve permitir localizar ativos, acompanhar preço e variação, atualizar os dados e escolher o que aparece nos widgets da tela inicial do dispositivo. Não criar alvos web ou desktop sem uma decisão explícita. O aplicativo é informativo; não inclui negociação nem recomendações de investimento.

## Estrutura e arquitetura

Ao iniciar o projeto, use `flutter create --platforms=android,ios .`. Organize `lib/` em `core/` (tema, rede, erros), `features/markets/` (modelos, fontes de dados e telas), `features/watchlist/` e `features/home_widgets/`; mantenha `test/` com a mesma divisão. Reserve `android/` para o App Widget nativo e `ios/` para a extensão WidgetKit. Separe interface, lógica de apresentação e acesso a dados. Toda cotação deve carregar símbolo, mercado, moeda, preço, variação, horário da cotação e fonte; nunca inferir que um valor é em tempo real.

## Dados e dependências

Planeje adaptadores para a **brapi** (B3/Ibovespa) e **Twelve Data** (mercados internacionais). Confirme cobertura, licença de exibição, limites e atraso de cada plano antes de ligar uma fonte real. Use `dio` para HTTP com timeout, `flutter_riverpod` para estado assíncrono, `intl` para números e datas e `home_widget` para compartilhar dados com os widgets. Mantenha os fornecedores substituíveis por interfaces e use respostas fixas apenas em testes e prévias identificadas como demonstração. Não inclua chaves de API no repositório nem em binários distribuídos; para produção, obtenha as cotações por um serviço que guarde as credenciais.

## Interface e widgets do dispositivo

Adote azul marinho escuro como fundo principal, preto para superfícies e branco para textos e detalhes; registre os tons exatos em tokens de tema quando criar o app. Mantenha contraste legível e não dependa só da cor para indicar alta ou queda. Exiba moeda, fonte e horário da última cotação; sinalize dados atrasados, ausência de rede e mercado fechado. Ofereça widgets pequenos e médios no Android e iOS com ativo selecionado, preço, variação e horário. Implemente a interface dos widgets em Kotlin/App Widget e SwiftUI/WidgetKit; `home_widget` faz a ponte de dados com Flutter. Atualize ao receber novas cotações no app e respeite os limites de atualização do sistema, sem prometer atualização contínua.

## Desenvolvimento e qualidade

Use Dart formatado por `dart format` e as regras de `flutter_lints`; nomes de arquivos em `snake_case`, classes em `UpperCamelCase` e variáveis em `lowerCamelCase`. Execute `flutter pub get`, `flutter analyze` e `flutter test` antes de concluir mudanças. Para executar, use `flutter run -d <device>`; valide o build Android com `flutter build apk` e o iOS em macOS com `flutter build ios --no-codesign`. Teste parsing, formatação, estados de erro e dados antigos, seleção da lista e payload dos widgets. Verifique instalação, redimensionamento, toque e atualização dos widgets em dispositivos reais de ambas as plataformas quando disponíveis. Documente no README configurações, provedores, limites e passos de execução. Atualize este guia quando mudar a arquitetura ou o fluxo de trabalho.
