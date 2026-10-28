# PocketValue

Aplicativo Flutter pessoal para acompanhar o Ibovespa e ativos brasileiros e internacionais, em Android e iOS.

## Executar

```bash
flutter pub get
flutter run -d <device>
```

Na primeira abertura, o app importa as chaves de `.env` para `flutter_secure_storage` (Keychain no iOS e armazenamento criptografado no Android). Ele aceita `BRAPI_API_KEY` e `TWELVE_DATA_API_KEY`; também reconhece a variável antiga `TWELV_DATA_API_KEY`. Chaves já salvas têm prioridade. Depois da importação, configurações feitas no app persistem com segurança. O `.env` é incluído no bundle local: mantenha-o fora do Git e não distribua APKs ou builds criados com suas chaves pessoais.

A busca brasileira funciona sem token. As cotações de PETR4, VALE3, MGLU3 e ITUB4 também podem ser consultadas sem chave; os demais ativos dependem do acesso disponível na conta. O app inicia com a lista pessoal vazia e tenta obter o Ibovespa. Se o plano não fornecer um ativo, a tela informa a indisponibilidade.

## Tela inicial

- Modo imersivo: oculta as barras do sistema e restaura a tela cheia ao voltar ao app ou fechar o teclado. Um gesto na borda revela temporariamente as barras no Android. As áreas seguras continuam protegendo o conteúdo de recortes da tela.
- Card do Ibovespa com pontos, variação, fonte e horário da cotação.
- Busca por nome ou símbolo, separada por mercado; ativos identificados também pela bolsa.
- Lista pessoal com filtros, remoção e reordenação pelo puxador no filtro **Todos**.
- Atualização manual pelo gesto de puxar, botão de atualizar ou menu de cada ativo.
- Cache e lista persistentes; erros de uma fonte não apagam cotações anteriores nem bloqueiam a outra fonte.
- Configurações de APIs e escolha do ativo para um futuro widget.

A escolha para widget e um snapshot versionado ficam salvos localmente. Os widgets nativos Android/iOS, a ponte `home_widget`, a atualização em segundo plano e a abertura por deep link pertencem à próxima etapa; ainda não é possível instalar um widget na tela inicial do dispositivo.

## Contratos e limites

As fontes de verdade são a [documentação brapi](https://brapi.dev/docs) e a [documentação Twelve Data](https://twelvedata.com/docs/introduction/overview).

| Operação | brapi | Twelve Data |
| --- | --- | --- |
| Cotação | `/api/v2/stocks/quote?symbols=...` | `/quote?symbol=...&exchange=...` |
| Busca | `/api/v2/tickers?search=...` | `/symbol_search?symbol=...&show_plan=true` |
| Credencial no header | `Authorization: Bearer <chave>` | `Authorization: apikey <chave>` |

O parser brapi usa `results[].data`. Na Twelve Data, preços podem vir como texto, e o horário da última cotação usa `last_quote_at`; o `timestamp` da vela não é tratado como horário da última negociação. Valores nulos permanecem indisponíveis. Não são inventados preços, horários ou estado de mercado.

O app reutiliza o cache por 30 minutos ao iniciar ou voltar ao primeiro plano. Atualizações manuais ignoram esse cache, mas respeitam bloqueios da API. Não há polling contínuo. O orçamento local conservador da Twelve Data permite até 8 créditos por minuto e 800 por dia UTC, persistidos entre sessões; consultas feitas fora deste app também consomem a conta e não entram nesse contador. Respostas 429 suspendem novas tentativas do fornecedor, respeitando `Retry-After` em segundos na brapi. Não há repetição automática de requisições.

Preço e horário recebido são armazenados separadamente. A interface mostra o horário da cotação no fuso local do dispositivo e sinaliza dados com mais de 30 minutos ou sem horário. Mercado aberto/fechado só é mostrado quando fornecido pela API. O app não garante tempo real.

## Organização

```text
lib/core/                    tema, formatação, armazenamento e credenciais
lib/features/markets/        adaptadores das APIs, modelos, telas e busca
lib/features/watchlist/      estado do painel, lista, cache e persistência
lib/features/home_widgets/  contrato do snapshot para a futura ponte nativa
test/                        testes sem consultas reais às APIs
```

Riverpod fornece o controller à interface; `ListenableBuilder` acompanha suas mudanças. Rede e persistência ficam fora dos componentes de apresentação. A skill [Mobile App Design Standards](https://github.com/awesome-skills/mobile-app-design) orienta contraste, alvos de toque e acessibilidade.

## Verificar

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Os testes cobrem os contratos HTTP com um adapter falso, parsing, campos ausentes, horários, rate limit, falhas parciais, cache, lista persistente e layout com texto ampliado. As cotações de teste são fictícias e não aparecem no aplicativo em execução. Um teste gera `/tmp/pocket-value-home.png` para revisão visual.

O build e os testes reais de iOS exigem macOS, Xcode e configuração de assinatura. `Runner.entitlements` habilita o acesso ao Keychain; confirme a configuração em um dispositivo antes de usar. Para distribuição futura, ajuste os identificadores de pacote, assinatura e licenças dos dados.
