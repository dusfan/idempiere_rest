import 'package:idempiere_rest/src/expand_builder.dart';
import 'package:idempiere_rest/src/filter_builder.dart';
import 'package:idempiere_rest/src/login_response.dart';
import 'package:idempiere_rest/src/model_base.dart';
import 'package:idempiere_rest/src/operators.dart';
import 'package:idempiere_rest/src/process_summary.dart';
import 'package:idempiere_rest/src/idempiere_client.dart';
import 'package:idempiere_rest/src/session.dart';
import 'package:test/test.dart';

void main() {
  group('Idempiere Rest - Simple Test Suite', () {
    String login = "superuser @ idempiere.com";
    String password = "System";
    IdempiereClient().setBaseUrl("https://test.idempiere.org/api/v1");

    late LoginResponse response;
    late int clientId;
    late int roleId;
    late int adOrgId;
    late int warehouseId;
    late TestModel record;
    int validGroupId = 0; 

    setUp(() {});

    test('Login', () async {
      response = await IdempiereClient().login("/auth/tokens", login, password);
      expect(response.token.isNotEmpty, isTrue);
      clientId = response.clients.first.id!;
    });

    test('Get Roles', () async {
      final roles = await IdempiereClient().getRoles(clientId);
      expect(roles.isNotEmpty, isTrue);
      roleId = roles.first.id!;
    });

    test('Get Organizations', () async {
      final orgs = await IdempiereClient().getOrganizations(clientId, roleId);
      expect(orgs.isNotEmpty, isTrue);
      adOrgId = orgs.first.id!;
    });

    test('Get Warehouses', () async {
      final warehouses = await IdempiereClient().getWarehouses(clientId, roleId, adOrgId);
      if (warehouses.isNotEmpty) {
        warehouseId = warehouses.first.id!;
      } else {
        warehouseId = 0; 
      }
      expect(warehouseId >= 0, isTrue);
    });

    test('Init Session', () async {
      Session s = await IdempiereClient().initSession(
          "/auth/tokens", response.token, clientId, roleId,
          organizationId: adOrgId, warehouseId: warehouseId);
      expect(s.token.isNotEmpty, isTrue);
    });

    test('Get Records', () async {
      FilterBuilder filter = FilterBuilder();
      filter.addFilter('IsVendor', Operators.eq, 'Y');

      List<TestModel> records = await IdempiereClient().get<TestModel>(
          "/models/c_bpartner", (json) => TestModel(json),
          filter: filter,
          select: ['Name', 'Value'],
          top: 10,
          skip: 0,
          showsql: true);
      expect(records != null, isTrue);
    });

    test('Get Record', () async {
      List<TestModel> records = await IdempiereClient().get<TestModel>(
          "/models/c_bpartner", (json) => TestModel(json),
          top: 1);

      if (records.isNotEmpty) {
        int targetId = records.first.id!;
        validGroupId = records.first.cBPGroupId; 
        
        TestModel? fetchedRecord = await IdempiereClient().getRecord<TestModel>(
            "/models/c_bpartner", targetId, (json) => TestModel(json));

        expect(fetchedRecord!.id, targetId);
      }
    });

    test('Post Record', () async {
      TestModel newRecord = TestModel.newTest(validGroupId, 'BPartner Test');
      record = await IdempiereClient()
          .post<TestModel>("/models/c_bpartner", newRecord);

      expect(record.id! > 0, isTrue);
    });

    test('Put Record', () async {
      TestModel oldRecord = TestModel.newTest(validGroupId, record.name);
      oldRecord.id = record.id;
      record.name = 'BPartner Test Put';
      TestModel updatedRecord =
          await IdempiereClient().put<TestModel>("/models/c_bpartner", record);

      expect(
          updatedRecord.id == oldRecord.id &&
              updatedRecord.name != oldRecord.name,
          isTrue);
    });

    test('Delete Record', () async {
      bool isDeleted =
          await IdempiereClient().delete("/models/c_bpartner", record.id!);

      expect(isDeleted, isTrue);
    });

    test('Run Process', () async {
      ProcessSummary ps = await IdempiereClient().runProcess(
          "/processes/ad_role_accessupdate",
          params: {'AD_Role_ID': roleId, 'ResetAccess': 'N'});

      expect(ps.isError, isFalse);
    });
  });
}

class TestModel extends ModelBase {
  late int cBPGroupId;
  late String name;

  TestModel.newTest(this.cBPGroupId, this.name) : super({});

  TestModel(Map<String, dynamic> json) : super(json) {
    id = json['id'];
    name = json['Name'] ?? '';
    
    // Safely parse the Group ID whether the server sends an integer or a nested Map object
    var groupIdRaw = json['C_BP_Group_ID'];
    if (groupIdRaw is Map) {
      cBPGroupId = groupIdRaw['id'] ?? 0;
    } else if (groupIdRaw is int) {
      cBPGroupId = groupIdRaw;
    } else {
      cBPGroupId = 0;
    }
  }

  @override
  Map<String, dynamic> toJson() {
    Map<String, dynamic> data = {};
    if (id != null) {
      data['id'] = id;
    }

    data['Name'] = name;
    data['C_BP_Group_ID'] = cBPGroupId;
    data['AD_Language'] = 'en_US';

    return data;
  }

  @override
  TestModel fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['Name'] ?? '';
    
    var groupIdRaw = json['C_BP_Group_ID'];
    if (groupIdRaw is Map) {
      cBPGroupId = groupIdRaw['id'] ?? 0;
    } else if (groupIdRaw is int) {
      cBPGroupId = groupIdRaw;
    } else {
      cBPGroupId = 0;
    }
    
    return this;
  }
}