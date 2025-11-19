import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../../../core/config/firebase_config.dart';
import '../models/music.dart';

class MusicImporter {
  static Future<int> importFromJson() async {
    try {
      // Lê o arquivo JSON dos assets
      final String jsonString =
          await rootBundle.loadString('musics.json');
      
      // Converte o JSON para uma lista de mapas
      final List<dynamic> jsonList = json.decode(jsonString);
      
      final firestore = FirebaseConfig.firestore;
      final musicsCollection = firestore.collection('musics');
      
      int importedCount = 0;
      int errorCount = 0;
      
      // Itera sobre cada música no JSON
      for (final jsonItem in jsonList) {
        try {
          // Converte o item JSON para MusicModel
          final music = MusicModel.fromJson(
            jsonItem as Map<String, dynamic>,
          );
          
          // Usa o ID da música como ID do documento no Firestore
          final musicDoc = musicsCollection.doc(music.id);
          
          // Verifica se o documento já existe
          final existingDoc = await musicDoc.get();
          
          if (!existingDoc.exists) {
            // Cria um novo documento no Firestore com o ID da música
            await musicDoc.set(music.toJson());
            importedCount++;
          } else {
            // Se já existe, atualiza o documento
            await musicDoc.update(music.toJson());
            importedCount++;
          }
        } catch (e) {
          errorCount++;
        }
      }
      
      return importedCount;
    } catch (e) {
      rethrow;
    }
  }
}

