/*
 * Copyright 2020 ACINQ SAS
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package fr.acinq.phoenix.legacy.db

import android.content.Context
import com.squareup.sqldelight.EnumColumnAdapter
import com.squareup.sqldelight.android.AndroidSqliteDriver

object AppDb {
  @Volatile
  private var instance: Database? = null

  val ready: Boolean
    get() = instance != null

  fun getInstance(context: Context): Database {
    return instance ?: synchronized(this) {
      instance ?: Database(
        driver = AndroidSqliteDriver(
          schema = Database.Schema,
          context = context,
          name = "phoenix-meta.db"
        ),
        PaymentMetaAdapter = PaymentMeta.Adapter(EnumColumnAdapter())
      ).also { instance = it }
    }
  }
}






