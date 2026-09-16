# Bancada de teste de anti-spoofing facial

Duas ferramentas complementares para validar um detector de ataques de apresentação/injeção
(PAD — Presentation Attack Detection) contra biometria facial, seguindo a terminologia da
norma **ISO/IEC 30107-3**.

- `index.html` — bancada de **um único frame**: injeta imagem/vídeo estático (webcam real,
  OBS Virtual Camera, ou upload de arquivo) e mede APCER/BPCER/ACER.
- `liveness.html` — detector de **prova de vida** (liveness): desafio-resposta com piscar,
  girar a cabeça e sorrir, mais sinais temporais (movimento, trajetória, proxy de pulso).

## Por que dois detectores, não um

Esta é a descoberta central do projeto, e vale citar no trabalho: **um heurístico de frame
único, por melhor que seja, tem teto baixo contra uma foto de boa qualidade.**

Medido nesta bancada: a heurística de 3 sinais do `index.html` (nitidez por variância do
Laplaciano, variância de saturação HSV, fração de pixels quase-brancos) devolveu
**score 0.07 de 1.0** (bem abaixo do limiar de 0.55) para uma foto de rosto nítida, bem
iluminada, com fundo de estúdio — ou seja, **deixou passar** um ataque de apresentação
clássico. Não é um bug: é o limite estrutural de qualquer classificador que olha só a
textura de um frame parado. Uma foto suficientemente boa tem textura de pele real, porque
**é** pele real fotografada — só que estática.

É por isso que a defesa de verdade não vive no `index.html`, e sim no `liveness.html`:
**tempo**, não textura, é o que uma foto não tem como fingir.

## Rodar a bancada de frame único (`index.html`)

`getUserMedia` só libera câmera em contexto seguro. Abra por `localhost`, não por `file://`:

```
cd C:\Users\Ataulpho\Desktop\anti-spoofing-bench
python -m http.server 8000 --bind 127.0.0.1
```

**O `--bind 127.0.0.1` não é opcional.** Sem ele, `python -m http.server` escuta em
`0.0.0.0` — medido nesta máquina: qualquer outro dispositivo na mesma rede Wi-Fi/LAN
(casa, hotel, coworking) consegue abrir `http://<seu-ip-de-rede>:8000/` e baixar
`minha-foto.jpg` direto, sem senha nenhuma, enquanto o servidor estiver no ar.

Abra `http://localhost:8000/index.html`.

**Injetar imagem estática pelo OBS:**
1. No OBS, adicione uma fonte **Imagem** apontando pro PNG/JPG de teste. Confirme que a foto
   aparece no preview grande do próprio OBS antes de seguir.
2. Ajuste a tela para 1280×720 (Configurações → Vídeo).
3. Em **Controles**, clique **Iniciar Câmera Virtual**.
4. Na bancada, **Liberar câmera** → escolha **OBS Virtual Camera** → **Iniciar fonte**.

Nota: a "OBS Virtual Camera" aparece na lista de câmeras mesmo com o OBS **fechado** (o
driver é instalado no sistema). Sem o OBS aberto e com uma fonte carregada, ela manda tela
preta — não é erro da bancada.

**Sem OBS, direto no arquivo (mais rápido para medir):** seção 5, botão **"Testar a MINHA
foto"** (rotulada como ataque) ou os campos **Imagens GENUÍNAS / Imagens de ATAQUE**.

**Medir:** rotule o feed/lote com a verdade conhecida. A bancada roda o detector e acumula
na matriz de confusão:

| | detectou GENUÍNO | detectou ATAQUE |
|---|---|---|
| **era GENUÍNO** | TN | FP → BPCER |
| **era ATAQUE** | FN → APCER | TP |

- **APCER** (Attack Presentation Classification Error Rate) — fração de ataques aceitos
  como genuínos. É a métrica que mais importa para segurança.
- **BPCER** (Bona Fide Presentation Classification Error Rate) — fração de usuários
  legítimos rejeitados. É a métrica que mais importa para usabilidade.
- **ACER** — média das duas, resumo único (mas nunca substitui olhar as duas separado).

## Rodar o detector de liveness (`liveness.html`)

Painel único: clique **"▶ Começar prova de vida"**. A câmera física é escolhida
automaticamente (pula OBS/DroidCam/SplitCam e outras virtuais). Ele pede 3 gestos, sorteados
de um total de 4 possíveis (piscar N vezes, virar esquerda, virar direita, sorrir), em ordem
aleatória, com um tempo de reação mínimo exigido — um vídeo pré-gravado não sabe de antemão
qual sequência vai ser pedida nem consegue reagir dentro da janela certa.

**Sinais implementados** (todos com `MediaPipe FaceMesh`, rodando 100% local em `mp/`, sem
CDN):

1. **Trava anti-estática** — movimento médio dos landmarks entre frames, normalizado pela
   largura do rosto (invariante à distância da câmera). Reprova quando ≥80% dos últimos 24
   frames ficam abaixo do piso de movimento — uma fração, não um máximo isolado, então um
   único tremor não desarma a trava.
2. **Piscar calibrado por usuário** — o limiar de abertura do olho (EAR) é medido no próprio
   usuário no primeiro segundo, não fixo, porque olho estreito com limiar fixo reprova gente
   viva.
3. **Trajetória de giro** — exige movimento consistente numa direção ao longo de vários
   frames (não só uma razão antes/depois), e corta na hora se detectar um salto brusco —
   isso derruba o ataque clássico de "duas fotos alternadas" (de frente e de perfil).
4. **Detector de corte** — um salto de movimento no meio do piscar ou do sorriso indica foto
   trocada, não gesto real.
5. **Ligação temporal** — a resposta ao desafio só vale se chegar depois de um tempo de
   reação humano plausível (≥250ms), contra vídeo pré-gravado que reage instantaneamente.
6. **Proxy de pulso (rPPG simplificado, informativo)** — variação do canal verde em duas
   regiões de pele (testa e bochecha), com estimativa grosseira de BPM por contagem de
   cruzamento de zero, janelada por tempo real. Correlação entre as duas regiões é mostrada
   como indício extra. **Não bloqueia o veredito sozinho** — é informação para revisão
   manual, porque uma estimativa ruim por luz fraca não pode reprovar quem está vivo.
7. **Sinal de câmera virtual** — se a fonte parece ser OBS/DroidCam/etc., um aviso aparece
   **no veredito**, mesmo quando o desafio é cumprido, para revisão manual.

**Autoteste embutido** (sem câmera): 13 casos sintéticos comprovam cada peça da lógica —
inclusive os dois casos que já foram bugs reais e ficaram documentados como regressão: olho
estreito sendo reprovado por limiar fixo, e um pico isolado desarmando a trava anti-estática.

## Limitação honesta que fica de fora

Nenhuma defesa de tela sozinha fecha 100% contra um **vídeo real** de alguém genuinamente
piscando e virando a cabeça (replay de alta qualidade, ou deepfake ao vivo bem feito). É
limite conhecido da área de PAD, não falha deste código — a literatura trata isso com sinais
adicionais como consistência 3D/paralaxe e detecção de moiré de tela, que ficam como próximo
passo natural do trabalho.

## Datasets públicos de PAD (para expandir a medição)

CASIA-FASD, Replay-Attack, OULU-NPU, CelebA-Spoof, SiW — todos citáveis e com protocolo de
avaliação estabelecido; o modo dataset da seção 5 do `index.html` aceita qualquer conjunto de
imagens rotuladas.

## O que este projeto não faz, de propósito

Nenhum arquivo aqui ajuda a fazer um site de terceiro aceitar uma câmera virtual sem o alerta
de "dispositivo não reconhecido". As duas bancadas existem para **medir se o detector
reprova** a fonte injetada — o oposto de contornar o detector de outra pessoa.
