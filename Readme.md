# CALORIEWISE: CUSTOM DIET AND WORKOUT PLANNER

## Description

This is a text file that describes how to run the files and application. The datasets are put inside the `model` folder inside the `app` folder, including the recipe and workout datasets, while the food image dataset is in the `img_classification.zip` file. Besides, details about the datasets are given below the dataset section.

## Datasets

### 1. Recipe Dataset

This recipe dataset is self-collected with a combination of data from Edamam Recipe Search API and Food.com - Recipes and Review, a public dataset from Kaggle. It has been organized and preprocessed.

Download from the links below to have more information:

- https://1drv.ms/x/c/a8034d40685ebc6b/EcdrpdfliyBAhuoyWA4EyaMBRyVb0eTDuY9hPnqj3nxnyg?e=7IvCWn
- https://www.kaggle.com/datasets/chewlingsee/caloriewise-recipe-dataset

### 2. Workout Dataset

This workout dataset is self-collected from Compendium of Physical Activities - 2024 Adult Compendium.

Source:

- https://pacompendium.com/adult-compendium/

The dataset has been saved into a CSV file and can be downloaded with the links below:

- https://1drv.ms/x/c/a8034d40685ebc6b/EeP7_UURx4lGoNQrhuhD3SABhMQC7jp4v5beDeLaKFGptg?e=rJaQvF
- https://www.kaggle.com/datasets/chewlingsee/caloriewise-workout-dataset

### 3. Food Image Dataset

The food classification model is trained using a public dataset from Kaggle named Food Image Classification Dataset.

The dataset can be downloaded from:

- https://www.kaggle.com/datasets/harishkumardatalab/food-image-classification-dataset

## Installation

1. Visual Studio Code  
   https://code.visualstudio.com/docs/?dv=win64user

2. Android Studio installation and setup  
   https://docs.flutter.dev/get-started/install/windows/mobile

3. Flutter  
   https://docs.flutter.dev/install/with-vs-code

4. MySQL Workbench 8.0 CE / XAMPP  
   https://dev.mysql.com/downloads/workbench/

5. Flutter extension

6. Dart extension

## How to Run the Source Code

First, extract all the zip files.

### Dataset

1. Run the `recipe1.ipynb` code to get data from Edamam Recipe Search API.
2. Run `recipe2.ipynb`, using Food.com - Recipes and Review, to get the final combined and cleaned recipe dataset CSV file.

### Image Recognition Model

1. Run `img_classification.ipynb` to train the model using the images from the `img` folder.

### Application

1. Run the `app.py` file from the `app` folder.
2. Run the `caloriewise` folder in Visual Studio Code.
3. Choose an Android Studio mobile emulator device.
4. In the menu bar of Visual Studio Code, go to the Run section and click **Run Without Debugging** to start the application.

## User Manual

1. Register an account using the sign in below the Login Page.
2. Fill up the personal survey form.
3. After successfully registering, login to the account using email and password.
4. Go to the Plan page to generate diet and workout plan.
5. After that, go back to the Home page to view the daily actual intake and the daily plan.
6. Tick the checkbox if that particular meal is completed. Otherwise, go to the Upload Page to add new intake.
7. In the Upload Page, click the upload container or gallery to upload an image from the gallery after saving an image, or take a photo using camera.
8. The predicted output will be printed at the search bar, and a list of relevant recipes will be shown.
9. The search bar can be used to search other food recipes by typing and clicking on the search icon.
10. Click on the recipe intake to view details and click on the add to intake button to add that recipe to the daily meal plan.
11. The Profile Page can be accessed through the sidebar at the top right corner.
12. The detailed information will be shown, and an edit button can be used to modify the personal information.
13. In the Tracking Page, the user may view the daily actual calorie intake history and the weight update progress through bar chart and line chart.
14. The user may update weight progress per week using the update container.
15. The latest weight will be stored and metrics data will be updated to ensure the next recommendation is accurate and consistent with the user's latest condition.
16. Lastly, logout the account using the logout button in the sidebar.
