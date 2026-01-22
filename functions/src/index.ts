/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

admin.initializeApp();

interface ChatMessage {
  text: string;
  userId: string;
  userName: string;
  mentionedUserIds?: string[];
  quotedMessageId?: string;
  quotedMessageText?: string;
  quotedMessageUserName?: string;
}

export const onMessageCreated = functions.firestore
  .document("services/{eventId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data() as ChatMessage;
    const {eventId, messageId} = context.params;

    // Se não há menções, não fazer nada
    if (!message.mentionedUserIds || message.mentionedUserIds.length === 0) {
      return null;
    }

    try {
      // Buscar informações do evento
      const eventDoc = await admin.firestore()
        .collection("services")
        .doc(eventId)
        .get();

      const eventName = eventDoc.data()?.name || "Evento";

      // Buscar FCM tokens dos usuários mencionados
      const userDocs = await Promise.all(
        message.mentionedUserIds.map((userId) =>
          admin.firestore().collection("users").doc(userId).get()
        )
      );

      // Filtrar usuários com FCM token, que não sejam o remetente
      // e que tenham a notificação de menção habilitada
      const tokens: string[] = [];
      userDocs.forEach((userDoc) => {
        if (userDoc.exists) {
          const userData = userDoc.data();
          const fcmToken = userData?.fcmToken;
          const userDocId = userDoc.id;

          // Não enviar notificação para o próprio remetente
          if (userDocId === message.userId) {
            return;
          }

          // Verificar se o usuário tem FCM token
          if (!fcmToken) {
            return;
          }

          // Verificar se a notificação de menção está habilitada
          // Se não existe o campo ou não contém 'chat_mention',
          // // está habilitada
          const disabledNotifications =
              userData?.disabled_notifications || [];
          const isMentionEnabled = !disabledNotifications
            .includes("chat_mention");

          if (isMentionEnabled) {
            tokens.push(fcmToken);
          }
        }
      });

      if (tokens.length === 0) {
        console.log("Nenhum token FCM encontrado para usuários mencionados");
        return null;
      }

      // Preparar texto da notificação
      const previewText = message.text.length > 50 ?
        message.text.substring(0, 50) + "..." :
        message.text;

      // Criar payload da notificação
      const payload: admin.messaging.MulticastMessage = {
        notification: {
          title: `@${message.userName} te mencionou`,
          body: `${eventName}: ${previewText}`,
        },
        data: {
          type: "chat_mention",
          eventId: eventId,
          messageId: messageId,
          senderId: message.userId,
          senderName: message.userName,
        },
        tokens: tokens,
        android: {
          priority: "high",
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      // Enviar notificações
      const response =
        await admin.messaging().sendEachForMulticast(payload);

      const logMessage =
        `Notificações enviadas: ${response.successCount}/${tokens.length}`;
      console.log(logMessage);

      if (response.failureCount > 0) {
        console.error("Alguns envios falharam:", response.responses);
      }

      return null;
    } catch (error) {
      console.error("Erro ao enviar notificações:", error);
      return null;
    }
  });

/**
 * Função agendada que roda toda sexta-feira às 9h (horário de Brasília)
 * Envia lembretes para diretorias de sociedades responsáveis pela liturgia
 * de eventos que acontecerão no próximo domingo
 */
export const fridayLiturgyReminder = functions
  .region("us-central1")
  .pubsub.schedule("0 9 * * 5")
  // Toda sexta-feira às 9h (horário UTC-3 = 12h UTC)
  .timeZone("America/Sao_Paulo")
  .onRun(async () => {
    try {
      console.log("Iniciando verificação de lembretes de liturgia...");

      // Calcular data do próximo domingo
      // Se hoje é sexta, o próximo domingo é em 2 dias
      const now = new Date();
      const currentDay = now.getDay(); // 0 = domingo, 5 = sexta
      let daysUntilSunday = 0;

      if (currentDay === 0) {
        // Se hoje é domingo, considerar o próximo domingo (7 dias)
        daysUntilSunday = 7;
      } else {
        // Calcular quantos dias até o próximo domingo
        daysUntilSunday = 7 - currentDay;
      }

      const nextSunday = new Date(now);
      nextSunday.setDate(now.getDate() + daysUntilSunday);
      nextSunday.setHours(0, 0, 0, 0);


      // Buscar eventos do próximo domingo
      const nextSundayStart = admin.firestore.Timestamp.fromDate(nextSunday);
      const nextSundayEnd = new Date(nextSunday);
      nextSundayEnd.setHours(23, 59, 59, 999);
      const nextSundayEndTimestamp =
        admin.firestore.Timestamp.fromDate(nextSundayEnd);

      const eventsSnapshot = await admin
        .firestore()
        .collection("services")
        .where("date", ">=", nextSundayStart)
        .where("date", "<=", nextSundayEndTimestamp)
        .get();

      if (eventsSnapshot.empty) {
        console.log("Nenhum evento encontrado para o próximo domingo");
        return null;
      }

      console.log(
        `Encontrados ${eventsSnapshot.size} eventos para o próximo domingo`
      );

      const notificationsToSend: Array<{
        userId: string;
        fcmToken: string;
        responsibilityType: string; // "liturgia" ou "aberturaEbd"
        societyName: string;
        eventId: string;
      }> = [];

      // Processar cada evento
      for (const eventDoc of eventsSnapshot.docs) {
        const eventData = eventDoc.data();
        const teams = eventData.teams || {};
        const liturgiaSocietyId = teams.liturgia;
        const aberturaEbdSocietyId = teams.aberturaEbd;

        // Processar sociedade responsável pela liturgia
        if (liturgiaSocietyId) {
          const societyDoc = await admin
            .firestore()
            .collection("societies")
            .doc(liturgiaSocietyId)
            .get();

          if (societyDoc.exists) {
            const societyData = societyDoc.data();
            const boardIds = societyData?.board || [];

            if (boardIds.length > 0) {
              const boardMembers = await Promise.all(
                boardIds.map((userId: string) =>
                  admin.firestore().collection("users").doc(userId).get()
                )
              );

              for (const memberDoc of boardMembers) {
                if (!memberDoc.exists) continue;

                const memberData = memberDoc.data();
                const fcmToken = memberData?.fcmToken;
                const userId = memberDoc.id;

                if (!fcmToken) continue;

                const disabledNotifications =
                  memberData?.disabled_notifications || [];
                const isEventReminderEnabled =
                  !disabledNotifications.includes("event_reminder");

                if (isEventReminderEnabled) {
                  notificationsToSend.push({
                    userId: userId,
                    fcmToken: fcmToken,
                    responsibilityType: "liturgia",
                    societyName: societyData?.name || "Sociedade",
                    eventId: eventDoc.id,
                  });
                }
              }
            }
          }
        }

        // Processar sociedade responsável pela abertura EBD
        if (aberturaEbdSocietyId) {
          const societyDoc = await admin
            .firestore()
            .collection("societies")
            .doc(aberturaEbdSocietyId)
            .get();

          if (societyDoc.exists) {
            const societyData = societyDoc.data();
            const boardIds = societyData?.board || [];

            if (boardIds.length > 0) {
              const boardMembers = await Promise.all(
                boardIds.map((userId: string) =>
                  admin.firestore().collection("users").doc(userId).get()
                )
              );

              for (const memberDoc of boardMembers) {
                if (!memberDoc.exists) continue;

                const memberData = memberDoc.data();
                const fcmToken = memberData?.fcmToken;
                const userId = memberDoc.id;

                if (!fcmToken) continue;

                const disabledNotifications =
                  memberData?.disabled_notifications || [];
                const isEventReminderEnabled =
                  !disabledNotifications.includes("event_reminder");

                if (isEventReminderEnabled) {
                  notificationsToSend.push({
                    userId: userId,
                    fcmToken: fcmToken,
                    responsibilityType: "aberturaEbd",
                    societyName: societyData?.name || "Sociedade",
                    eventId: eventDoc.id,
                  });
                }
              }
            }
          }
        }
      }

      // Agrupar por usuário e tipo de responsabilidade
      const userNotifications = new Map<
        string,
        {
          fcmToken: string;
          liturgiaSocieties: string[];
          aberturaEbdSocieties: string[];
          liturgiaEventIds: string[];
          aberturaEbdEventIds: string[];
        }
      >();

      // Declarar variáveis para liturgia
      // (fora do bloco if para poder usar depois)
      let liturgySuccessCount = 0;
      let liturgyFailureCount = 0;

      // Processar notificações de diretoria (se houver)
      if (notificationsToSend.length > 0) {
        for (const notif of notificationsToSend) {
          if (!userNotifications.has(notif.userId)) {
            userNotifications.set(notif.userId, {
              fcmToken: notif.fcmToken,
              liturgiaSocieties: [],
              aberturaEbdSocieties: [],
              liturgiaEventIds: [],
              aberturaEbdEventIds: [],
            });
          }
          const userNotif = userNotifications.get(notif.userId);
          if (!userNotif) continue;

          if (
            notif.responsibilityType === "liturgia" &&
            !userNotif.liturgiaSocieties.includes(notif.societyName)
          ) {
            userNotif.liturgiaSocieties.push(notif.societyName);
            // Adicionar eventId se ainda não estiver na lista
            if (!userNotif.liturgiaEventIds.includes(notif.eventId)) {
              userNotif.liturgiaEventIds.push(notif.eventId);
            }
          }
          if (
            notif.responsibilityType === "aberturaEbd" &&
            !userNotif.aberturaEbdSocieties.includes(notif.societyName)
          ) {
            userNotif.aberturaEbdSocieties.push(notif.societyName);
            // Adicionar eventId se ainda não estiver na lista
            if (!userNotif.aberturaEbdEventIds.includes(notif.eventId)) {
              userNotif.aberturaEbdEventIds.push(notif.eventId);
            }
          }
        }

        // Enviar notificações de diretoria
        const messages: admin.messaging.Message[] = [];

        for (const [, userNotif] of userNotifications.entries()) {
          // Validar FCM token
          const userFcmToken = userNotif.fcmToken?.trim();
          if (!userFcmToken || userFcmToken === "") {
            continue;
          }

          // Se tem responsabilidade por liturgia
          if (userNotif.liturgiaSocieties.length > 0) {
            const societyText = userNotif.liturgiaSocieties.join(", ");
            const bodyText =
              `${societyText}: Defina a liturgia para culto do próximo domingo`;
            // Usar o primeiro eventId (evento mais próximo)
            const eventId = userNotif.liturgiaEventIds.length > 0 ?
              userNotif.liturgiaEventIds[0] :
              "";
            messages.push({
              notification: {
                title: "Lembrete de Liturgia",
                body: bodyText,
              },
              data: {
                type: "event_reminder",
                responsibilityType: "liturgia",
                societyNames: societyText,
                eventId: eventId,
              },
              token: userFcmToken,
              android: {
                priority: "high",
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                    badge: 1,
                  },
                },
              },
            });
          }

          // Se tem responsabilidade por abertura EBD
          if (userNotif.aberturaEbdSocieties.length > 0) {
            const societyText = userNotif.aberturaEbdSocieties.join(", ");
            const bodyText =
              `${societyText}: Defina a liturgia para a EBD do próximo domingo`;
            // Usar o primeiro eventId (evento mais próximo)
            const eventId = userNotif.aberturaEbdEventIds.length > 0 ?
              userNotif.aberturaEbdEventIds[0] :
              "";
            messages.push({
              notification: {
                title: "Lembrete de Liturgia",
                body: bodyText,
              },
              data: {
                type: "event_reminder",
                responsibilityType: "aberturaEbd",
                societyNames: societyText,
                eventId: eventId,
              },
              token: userFcmToken,
              android: {
                priority: "high",
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                    badge: 1,
                  },
                },
              },
            });
          }
        }

        // Enviar notificações em lote (diretorias)
        if (messages.length > 0) {
          try {
            // Usar send individual para evitar problemas com sendAll
            // sendAll pode ter problemas com tokens inválidos
            for (const message of messages) {
              try {
                await admin.messaging().send(message);
                liturgySuccessCount++;
                console.log(
                  "Notificação de diretoria enviada com sucesso"
                );
              } catch (sendError) {
                liturgyFailureCount++;
                console.error(
                  "Erro ao enviar notificação de diretoria individual:",
                  sendError
                );
                // Se for erro de token inválido, logar mas continuar
                if (sendError instanceof Error) {
                  if (sendError.message.includes("invalid") ||
                      sendError.message.includes("not found") ||
                      sendError.message.includes("404")) {
                    console.log(
                      "Token FCM inválido ou expirado, pulando..."
                    );
                  }
                }
              }
            }
          } catch (error) {
            console.error("Erro ao enviar notificações de diretoria:", error);
            // Continuar mesmo com erro, não bloquear processamento de escalados
          }
        }

        const liturgyLogMessage =
          `Lembretes de liturgia enviados:
${liturgySuccessCount}/${messages.length} ` +
          `(${liturgyFailureCount} falhas)`;
        console.log(liturgyLogMessage);
      } else {
        console.log("Nenhuma notificação de diretoria para enviar");
      }

      // ============================================
      // PARTE 2: Notificações para usuários escalados
      // ============================================

      const scaledUserNotifications: Array<{
        userId: string;
        fcmToken: string;
        eventName: string;
        eventId: string;
      }> = [];

      // Processar cada evento novamente para buscar usuários escalados
      for (const eventDoc of eventsSnapshot.docs) {
        const eventData = eventDoc.data();
        const eventName = eventData.name || "Evento";
        const eventId = eventDoc.id;
        const people = eventData.people || {};

        // Coletar todos os IDs de usuários escalados
        const scaledUserIds = new Set<string>();

        // Adicionar IDs de cada tipo de escala
        if (Array.isArray(people.elo)) {
          people.elo.forEach((id: string) => scaledUserIds.add(id));
        }
        if (Array.isArray(people.preacher)) {
          people.preacher.forEach((id: string) => scaledUserIds.add(id));
        }
        if (Array.isArray(people.lead)) {
          people.lead.forEach((id: string) => scaledUserIds.add(id));
        }
        if (Array.isArray(people.soundImage)) {
          people.soundImage.forEach((id: string) => scaledUserIds.add(id));
        }
        if (Array.isArray(people.diaconia)) {
          people.diaconia.forEach((id: string) => scaledUserIds.add(id));
        }
        if (
          people.eloWithInstruments &&
          typeof people.eloWithInstruments === "object"
        ) {
          Object.keys(people.eloWithInstruments).forEach((id: string) =>
            scaledUserIds.add(id)
          );
        }

        if (scaledUserIds.size === 0) {
          continue;
        }

        // Buscar dados dos usuários escalados
        const userDocs = await Promise.all(
          Array.from(scaledUserIds).map((userId) =>
            admin.firestore().collection("users").doc(userId).get()
          )
        );

        // Preparar notificações para usuários escalados
        // Usar um Set para rastrear usuários já processados para este evento
        const processedUsersForEvent = new Set<string>();

        for (const userDoc of userDocs) {
          if (!userDoc.exists) continue;

          const userData = userDoc.data();
          const fcmToken = userData?.fcmToken;
          const userId = userDoc.id;

          // Verificar se já foi processado para este evento
          if (processedUsersForEvent.has(userId)) {
            console.log(
              `Usuário ${userId} já processado para evento ${eventId}, ` +
              "pulando duplicata"
            );
            continue;
          }

          // Verificar se tem FCM token
          if (!fcmToken) {
            continue;
          }

          // Verificar se a notificação de lembrete de evento está habilitada
          const disabledNotifications =
            userData?.disabled_notifications || [];
          const isEventReminderEnabled =
            !disabledNotifications.includes("event_reminder");

          if (isEventReminderEnabled && fcmToken) {
            // Verificar se já foi adicionado para este evento (segurança extra)
            const alreadyAdded = scaledUserNotifications.some(
              (n) => n.userId === userId && n.eventId === eventId
            );

            if (!alreadyAdded) {
              scaledUserNotifications.push({
                userId: userId,
                fcmToken: fcmToken,
                eventName: eventName,
                eventId: eventId,
              });
              processedUsersForEvent.add(userId);
            } else {
              console.log(
                `Usuário ${userId} já foi adicionado para evento ${eventId}, ` +
                "pulando duplicata"
              );
            }
          }
        }
      }

      if (scaledUserNotifications.length === 0) {
        return null;
      }

      // Agrupar por usuário (evitar duplicatas se usuário está escalado
      // em múltiplos eventos)
      const userScaledNotifications = new Map<
        string,
        {fcmToken: string; events: Array<{name: string; id: string}>}
      >();

      // Agrupar por usuário para garantir apenas uma notificação por usuário
      // mesmo que esteja escalado em múltiplos eventos
      for (const notif of scaledUserNotifications) {
        if (!userScaledNotifications.has(notif.userId)) {
          userScaledNotifications.set(notif.userId, {
            fcmToken: notif.fcmToken,
            events: [],
          });
        }
        const userNotif = userScaledNotifications.get(notif.userId);
        if (!userNotif) continue;

        // Evitar duplicatas do mesmo evento
        if (!userNotif.events.some((e) => e.id === notif.eventId)) {
          userNotif.events.push({
            name: notif.eventName,
            id: notif.eventId,
          });
        }
      }

      // Log de diagnóstico: verificar agrupamento
      console.log(
        `Coletadas ${scaledUserNotifications.length} notificações, ` +
        `agrupadas em ${userScaledNotifications.size} usuários únicos`
      );

      // Preparar mensagens para usuários escalados
      const scaledMessages: admin.messaging.Message[] = [];
      // Rastrear tokens já processados
      const processedTokens = new Set<string>();

      for (const [userId, userNotif] of userScaledNotifications.entries()) {
        // Validar FCM token antes de adicionar à lista
        const fcmToken = userNotif.fcmToken?.trim();
        if (!fcmToken || fcmToken === "") {
          console.log(`
            FCM token inválido ou vazio para usuário ${userId}, pulando...
          `);
          continue;
        }

        // Verificar se este token já foi processado (evitar duplicatas)
        if (processedTokens.has(fcmToken)) {
          console.log(
            `Token FCM ${fcmToken.substring(0, 20)}... já foi processado, ` +
            `pulando duplicata para usuário ${userId}`
          );
          continue;
        }

        // Validar formato básico do token FCM
        if (fcmToken.length < 100 || fcmToken.length > 200) {
          console.log(`Token FCM com formato inválido para usuário ${userId}`);
          continue;
        }

        if (fcmToken.startsWith("http://") ||
            fcmToken.startsWith("https://") ||
            fcmToken.includes("<!DOCTYPE")) {
          console.log(`
            Token FCM com formato inválido (URL) para usuário ${userId}
          `);
          continue;
        }

        scaledMessages.push({
          notification: {
            title: "Lembrete de Evento",
            body: "Você está escalado para o culto do próximo domingo",
          },
          data: {
            type: "event_reminder",
            eventIds: userNotif.events.map((e) => e.id).join(","),
          },
          token: fcmToken,
          android: {
            priority: "high",
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        });

        // Marcar token como processado
        processedTokens.add(fcmToken);
      }

      // Enviar notificações para usuários escalados
      if (scaledMessages.length > 0) {
        let scaledSuccessCount = 0;
        let scaledFailureCount = 0;

        try {
          for (const message of scaledMessages) {
            try {
              await admin.messaging().send(message);
              scaledSuccessCount++;
            } catch (sendError) {
              scaledFailureCount++;
              console.error("Erro ao enviar notificação:", sendError);
            }
          }

          const scaledLogMessage =
            `Lembretes para escalados enviados: ${scaledSuccessCount}/` +
            `${scaledMessages.length} (${scaledFailureCount} falhas)`;
          console.log(scaledLogMessage);

          const totalLogMessage =
            `Total: ${liturgySuccessCount +
              scaledSuccessCount} notificações enviadas`;
          console.log(totalLogMessage);
        } catch (error) {
          console.error("Erro ao enviar notificações de escalados:", error);
          // Mesmo com erro, não retornar null aqui para não bloquear
        }
      } else {
        console.log("Nenhuma notificação para usuários escalados");
      }

      return null;
    } catch (error) {
      console.error("Erro crítico ao enviar lembretes:", error);
      // Log mais detalhado do erro
      if (error instanceof Error) {
        console.error("Mensagem de erro:", error.message);
        console.error("Stack trace:", error.stack);
      }
      return null;
    }
  });

/**
 * Função agendada que roda toda segunda-feira às 9h (horário de Brasília)
 * Envia lembretes para diretorias de sociedades responsáveis pela
 * "Reunião de oração" de eventos que acontecerão na próxima quarta-feira
 */
export const mondayPrayerMeetingReminder = functions
  .region("us-central1")
  .pubsub.schedule("0 9 * * 1") // Toda segunda-feira às 9h
  .timeZone("America/Sao_Paulo")
  .onRun(async () => {
    try {
      const logMessage =
        "Iniciando verificação de lembretes de reunião de oração...";
      console.log(logMessage);

      // Calcular data da próxima quarta-feira
      const now = new Date();
      const currentDay = now.getDay(); // 0 = domingo, 3 = quarta
      let daysUntilWednesday = 0;

      if (currentDay === 3) {
        // Se hoje é quarta, considerar a próxima quarta (7 dias)
        daysUntilWednesday = 7;
      } else if (currentDay < 3) {
        // Se ainda não chegou na quarta desta semana
        daysUntilWednesday = 3 - currentDay;
      } else {
        // Se já passou a quarta desta semana
        daysUntilWednesday = 7 - (currentDay - 3);
      }

      const nextWednesday = new Date(now);
      nextWednesday.setDate(now.getDate() + daysUntilWednesday);
      nextWednesday.setHours(0, 0, 0, 0);

      // Buscar eventos da próxima quarta-feira
      const nextWednesdayStart =
        admin.firestore.Timestamp.fromDate(nextWednesday);
      const nextWednesdayEnd = new Date(nextWednesday);
      nextWednesdayEnd.setHours(23, 59, 59, 999);
      const nextWednesdayEndTimestamp =
        admin.firestore.Timestamp.fromDate(nextWednesdayEnd);

      const eventsSnapshot = await admin
        .firestore()
        .collection("services")
        .where("date", ">=", nextWednesdayStart)
        .where("date", "<=", nextWednesdayEndTimestamp)
        .get();

      if (eventsSnapshot.empty) {
        console.log("Nenhum evento encontrado para a próxima quarta-feira");
        return null;
      }

      console.log(
        `Encontrados ${eventsSnapshot.size} eventos para a próxima quarta-feira`
      );

      const notificationsToSend: Array<{
        userId: string;
        fcmToken: string;
        societyName: string;
        eventId: string;
      }> = [];

      // Processar cada evento
      for (const eventDoc of eventsSnapshot.docs) {
        const eventData = eventDoc.data();
        const teams = eventData.teams || {};
        const reuniaoOracaoSocietyId = teams.reuniaoOracao;

        // Se não tem sociedade responsável pela reunião de oração, pular
        if (!reuniaoOracaoSocietyId) {
          continue;
        }

        // Buscar sociedade
        const societyDoc = await admin
          .firestore()
          .collection("societies")
          .doc(reuniaoOracaoSocietyId)
          .get();

        if (!societyDoc.exists) {
          const errorMessage =
            `Sociedade ${reuniaoOracaoSocietyId} não encontrada ` +
            `para evento ${eventDoc.id}`;
          console.log(errorMessage);
          continue;
        }

        const societyData = societyDoc.data();
        const boardIds = societyData?.board || [];

        if (boardIds.length === 0) {
          console.log(
            `Sociedade ${societyData?.name} não tem membros na diretoria`
          );
          continue;
        }

        // Buscar dados dos membros da diretoria
        const boardMembers = await Promise.all(
          boardIds.map((userId: string) =>
            admin.firestore().collection("users").doc(userId).get()
          )
        );

        // Preparar notificações
        // Usar um Set para rastrear usuários já processados para este evento
        const processedUsersForEvent = new Set<string>();

        for (const memberDoc of boardMembers) {
          if (!memberDoc.exists) continue;

          const memberData = memberDoc.data();
          const fcmToken = memberData?.fcmToken;
          const userId = memberDoc.id;

          // Verificar se já foi processado para este evento
          if (processedUsersForEvent.has(userId)) {
            console.log(
              `Usuário ${userId} já processado para evento ${eventDoc.id}, ` +
              "pulando duplicata"
            );
            continue;
          }

          // Verificar se tem FCM token
          if (!fcmToken) {
            continue;
          }

          // Verificar se a notificação de lembrete de evento está habilitada
          const disabledNotifications =
            memberData?.disabled_notifications || [];
          const isEventReminderEnabled =
            !disabledNotifications.includes("event_reminder");

          if (isEventReminderEnabled) {
            notificationsToSend.push({
              userId,
              fcmToken,
              societyName: societyData?.name || "Sociedade",
              eventId: eventDoc.id,
            });
            processedUsersForEvent.add(userId);
          }
        }
      }

      if (notificationsToSend.length === 0) {
        console.log("Nenhuma notificação para enviar");
        return null;
      }

      // Agrupar por usuário (evitar duplicatas)
      const userNotifications = new Map<
        string,
        {fcmToken: string; societies: string[]; eventIds: string[]}
      >();

      for (const notif of notificationsToSend) {
        if (!userNotifications.has(notif.userId)) {
          userNotifications.set(notif.userId, {
            fcmToken: notif.fcmToken,
            societies: [],
            eventIds: [],
          });
        }
        const userNotif = userNotifications.get(notif.userId);
        if (!userNotif) continue;

        if (!userNotif.societies.includes(notif.societyName)) {
          userNotif.societies.push(notif.societyName);
        }
        // Adicionar eventId se ainda não estiver na lista
        if (!userNotif.eventIds.includes(notif.eventId)) {
          userNotif.eventIds.push(notif.eventId);
        }
      }

      // Preparar mensagens
      const messages: admin.messaging.Message[] = [];
      // Rastrear tokens já processados
      const processedTokens = new Set<string>();

      for (const [userId, userNotif] of userNotifications.entries()) {
        // Validar FCM token
        const userFcmToken = userNotif.fcmToken?.trim();
        if (!userFcmToken || userFcmToken === "") {
          console.log(`
            FCM token inválido ou vazio para usuário ${userId}, pulando...
          `);
          continue;
        }

        // Verificar se este token já foi processado (evitar duplicatas)
        if (processedTokens.has(userFcmToken)) {
          continue;
        }

        // Validar formato básico do token FCM
        if (userFcmToken.length < 100 || userFcmToken.length > 200) {
          console.log(`Token FCM com formato inválido para usuário ${userId}`);
          continue;
        }

        if (userFcmToken.startsWith("http://") ||
            userFcmToken.startsWith("https://") ||
            userFcmToken.includes("<!DOCTYPE")) {
          console.log(`
            Token FCM com formato inválido (URL) para usuário ${userId}
          `);
          continue;
        }

        const societyText = userNotif.societies.join(", ");
        const bodyText =
          `${societyText}: Defina a liturgia para reunião de oração ` +
           "da próxima quarta-feira";
        // Usar o primeiro eventId (evento mais próximo)
        const eventId = userNotif.eventIds.length > 0 ?
          userNotif.eventIds[0] :
          "";

        messages.push({
          notification: {
            title: "Lembrete de Reunião de Oração",
            body: bodyText,
          },
          data: {
            type: "event_reminder",
            responsibilityType: "reuniaoOracao",
            societyNames: societyText,
            eventId: eventId,
          },
          token: userFcmToken,
          android: {
            priority: "high",
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        });

        // Marcar token como processado
        processedTokens.add(userFcmToken);
      }

      // Enviar notificações em lote
      const batchSize = 500;
      let successCount = 0;
      let failureCount = 0;

      for (let i = 0; i < messages.length; i += batchSize) {
        const batch = messages.slice(i, i + batchSize);
        const response = await admin.messaging().sendAll(batch);

        successCount += response.successCount;
        failureCount += response.failureCount;

        if (response.failureCount > 0) {
          console.error(
            `Alguns envios falharam no lote ${i / batchSize + 1}:`,
            response.responses
          );
        }
      }

      const prayerLogMessage =
        `Lembretes de reunião de oração enviados: ${successCount}/` +
        `${messages.length} (${failureCount} falhas)`;
      console.log(prayerLogMessage);

      return null;
    } catch (error) {
      console.error("Erro ao enviar lembretes de reunião de oração:", error);
      return null;
    }
  });

/**
 * Função agendada que roda nos dias 15 e 20 de cada mês
 * às 9h (horário de Brasília)
 * Envia lembretes para membros da sociedade ELO (Equipe de Louvor)
 * para definirem suas disponibilidades para o mês seguinte
 */
export const eloAvailabilityReminder = functions
  .region("us-central1")
  .pubsub.schedule("0 9 15,20 * *") // Dias 15 e 20 de cada mês às 9h
  .timeZone("America/Sao_Paulo")
  .onRun(async () => {
    try {
      // Buscar sociedade ELO pelo nome
      const eloSocietySnapshot = await admin
        .firestore()
        .collection("societies")
        .where("name", "==", "ELO")
        .limit(1)
        .get();

      if (eloSocietySnapshot.empty) {
        console.log("Sociedade ELO não encontrada");
        return null;
      }

      const eloSociety = eloSocietySnapshot.docs[0];
      const eloSocietyData = eloSociety.data();
      const membersIds = eloSocietyData.members || [];

      // Apenas membros devem receber notificação (não diretoria)
      // Pois usuários da diretoria também estão na lista de membros
      if (membersIds.length === 0) {
        console.log("Nenhum membro encontrado na sociedade ELO");
        return null;
      }

      console.log(`Encontrados ${membersIds.length} membros da ELO`);

      // Buscar dados dos usuários e seus FCM tokens
      const userDocs = await Promise.all(
        membersIds.map((userId: string) =>
          admin.firestore().collection("users").doc(userId).get()
        )
      );

      const messages: admin.messaging.Message[] = [];
      const processedTokens = new Set<string>();

      for (const userDoc of userDocs) {
        if (!userDoc.exists) continue;

        const userData = userDoc.data();
        const fcmToken = userData?.fcmToken;
        const userId = userDoc.id;

        // Verificar se tem FCM token
        if (!fcmToken) {
          continue;
        }

        // Validar FCM token
        const userFcmToken = fcmToken?.trim();
        if (!userFcmToken || userFcmToken === "") {
          continue;
        }

        // Verificar se este token já foi processado (evitar duplicatas)
        if (processedTokens.has(userFcmToken)) {
          continue;
        }

        // Validar formato básico do token FCM
        if (userFcmToken.length < 100 || userFcmToken.length > 200) {
          console.log(`Token FCM com formato inválido para usuário ${userId}`);
          continue;
        }

        if (
          userFcmToken.startsWith("http://") ||
          userFcmToken.startsWith("https://") ||
          userFcmToken.includes("<!DOCTYPE")
        ) {
          console.log(
            `Token FCM com formato inválido (URL) para usuário ${userId}`
          );
          continue;
        }

        // Verificar se a notificação de disponibilidade está habilitada
        const disabledNotifications = userData?.disabled_notifications || [];
        const isAvailabilityReminderEnabled =
          !disabledNotifications.includes("elo_availability_reminder");

        if (isAvailabilityReminderEnabled) {
          // Calcular qual é o próximo mês
          const now = new Date();
          const nextMonth = new Date(now);
          nextMonth.setMonth(now.getMonth() + 1);
          const monthName = nextMonth.toLocaleString(
            "pt-BR",
            {month: "long"}
          );

          messages.push({
            notification: {
              title: "Lembrete de Disponibilidade",
              body: `Não esqueça de informar sua
              disponibilidade para ${monthName}`,
            },
            data: {
              type: "elo_availability_reminder",
            },
            token: userFcmToken,
            android: {
              priority: "high",
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                  badge: 1,
                },
              },
            },
          });

          // Marcar token como processado
          processedTokens.add(userFcmToken);
        }
      }

      if (messages.length === 0) {
        console.log("Nenhuma notificação de disponibilidade para enviar");
        return null;
      }

      // Enviar notificações em lote
      let successCount = 0;
      let failureCount = 0;

      for (const message of messages) {
        try {
          await admin.messaging().send(message);
          successCount++;
        } catch (sendError) {
          failureCount++;
          console.error(
            "Erro ao enviar notificação de disponibilidade:",
            sendError
          );
        }
      }

      const logMessage =
        `Lembretes de disponibilidade ELO enviados: ${successCount}/` +
        `${messages.length} (${failureCount} falhas)`;
      console.log(logMessage);

      return null;
    } catch (error) {
      console.error("Erro ao enviar lembretes de disponibilidade ELO:", error);
      return null;
    }
  });
