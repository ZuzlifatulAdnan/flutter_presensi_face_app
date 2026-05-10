import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../data/datasources/user_remote_datasource.dart';

part 'update_password_bloc.freezed.dart';
part 'update_password_event.dart';
part 'update_password_state.dart';

class UpdatePasswordBloc extends Bloc<UpdatePasswordEvent, UpdatePasswordState> {
  final UserRemoteDatasource datasource;
  UpdatePasswordBloc(
    this.datasource,
  ) : super(_Initial()) {
    on<_UpdatePassword>(
      (event, emit) async {
        emit(_Loading());

        final result = await datasource.updatePassword(
            event.oldPassword, event.newPassword, event.confirmPassword);
        result.fold(
          (l) => emit(_Error(l)),
          (r) => emit(_Success(r)),
        );
      },
    );
  }
}
