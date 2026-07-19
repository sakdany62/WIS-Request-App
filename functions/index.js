// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.createUser = functions.https.onCall(async (data, context) => {
  // 1. ពិនិត្យថាអ្នកប្រើជា Admin
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }
  
  const callerUid = context.auth.uid;
  const callerDoc = await admin.firestore().collection('users').doc(callerUid).get();
  
  if (!callerDoc.exists || callerDoc.data()?.roleId !== '1') {
    throw new functions.https.HttpsError('permission-denied', 'Must be admin');
  }
  
  // 2. បង្កើត User
  const { 
    email, 
    password, 
    fullName, 
    username, 
    phone, 
    roleId, 
    departmentId, 
    department, 
    status 
  } = data;
  
  try {
    // Create user in Firebase Auth
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: fullName,
    });
    
    // Create user in Firestore
    await admin.firestore().collection('users').doc(userRecord.uid).set({
      userId: userRecord.uid,
      email,
      fullName,
      username,
      phone,
      roleId,
      departmentId: departmentId || null,
      department: department || null,
      status,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    return { 
      success: true, 
      uid: userRecord.uid,
      message: 'User created successfully' 
    };
  } catch (error) {
    console.error('Error creating user:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});